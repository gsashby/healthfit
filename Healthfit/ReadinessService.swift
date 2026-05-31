//
//  ReadinessService.swift
//  Queries HealthKit for HRV, sleep, and resting heart rate; computes a daily
//  readiness score; enables background delivery; schedules the morning briefing
//  notification; and surfaces a write path for completed workouts.
//
//  Phase 2 — HK data is real when a Watch is paired. When no data exists (simulator,
//  first launch, no Watch) latestData is nil and callers fall back to MockData.
//

import Foundation
import HealthKit
import UserNotifications

// MARK: - ReadinessData

/// Computed health metrics for today. Replaces the mock ReadinessState toggle
/// for the state/score/vitals fields of ReadinessSnapshot.
struct ReadinessData {
    let state: ReadinessState
    let score: Int          // 0–100
    let vitals: [Vital]
    let reasoning: String
}

// MARK: - ReadinessService

@MainActor
final class ReadinessService: ObservableObject {

    @Published var latestData: ReadinessData? = nil
    @Published var isLoading: Bool = false

    private let store = HKHealthStore()

    // MARK: HealthKit type sets

    static let readTypes: Set<HKObjectType> = {
        var s = Set<HKObjectType>()
        let qtIds: [HKQuantityTypeIdentifier] = [
            .heartRateVariabilitySDNN,
            .restingHeartRate,
            .activeEnergyBurned
        ]
        qtIds.compactMap { HKQuantityType.quantityType(forIdentifier: $0) }.forEach { s.insert($0) }
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) { s.insert(sleep) }
        s.insert(HKObjectType.workoutType())
        return s
    }()

    static let shareTypes: Set<HKSampleType> = [HKObjectType.workoutType()]

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try await store.requestAuthorization(toShare: Self.shareTypes, read: Self.readTypes)
        // HealthKit never throws when the user taps "Don't Allow" — it silently succeeds.
        // Check the one type we can inspect post-auth (workout is in shareTypes, so its
        // status is readable). Throw if it's denied so callers don't mark the app as connected.
        guard store.authorizationStatus(for: HKObjectType.workoutType()) != .sharingDenied else {
            throw HKError(.errorAuthorizationDenied)
        }
        await fetchReadiness()
        await enableBackgroundDelivery()
        await requestNotificationPermission()
    }

    // MARK: - Fetch & compute

    func fetchReadiness() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        async let hrv        = fetchLatestHRV()
        async let hrvBase    = fetchHRVBaseline()
        async let rhr        = fetchLatestRHR()
        async let rhrBase    = fetchRHRBaseline()
        async let sleep      = fetchLastNightSleep()

        let (hrvVal, hrvBaseline, rhrVal, rhrBaseline, sleepResult) =
            await (hrv, hrvBase, rhr, rhrBase, sleep)

        let data = computeReadiness(
            hrv: hrvVal, hrvBaseline: hrvBaseline,
            rhr: rhrVal, rhrBaseline: rhrBaseline,
            sleep: sleepResult
        )
        latestData = data
    }

    // MARK: - HealthKit queries

    private func fetchLatestHRV() async -> Double? {
        await fetchLatestQuantity(.heartRateVariabilitySDNN,
                                  unit: HKUnit.secondUnit(with: .milli),
                                  withinDays: 2)
    }

    private func fetchHRVBaseline() async -> Double? {
        await fetchAverage(.heartRateVariabilitySDNN,
                           unit: HKUnit.secondUnit(with: .milli),
                           days: 14)
    }

    private func fetchLatestRHR() async -> Double? {
        await fetchLatestQuantity(.restingHeartRate,
                                  unit: .count().unitDivided(by: .minute()),
                                  withinDays: 2)
    }

    private func fetchRHRBaseline() async -> Double? {
        await fetchAverage(.restingHeartRate,
                           unit: .count().unitDivided(by: .minute()),
                           days: 14)
    }

    struct SleepResult {
        let hours: Double
        let score: Int  // 0–100
    }

    private func fetchLastNightSleep() async -> SleepResult? {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }

        // Window: yesterday noon → today noon captures overnight sleep
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let windowEnd   = calendar.date(byAdding: .hour, value: 12, to: todayStart)!
        let windowStart = calendar.date(byAdding: .day, value: -1, to: windowEnd)!

        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd,
                                                     options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [HKSamplePredicate<HKCategorySample>.categorySample(
                type: sleepType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        guard let samples = try? await descriptor.result(for: store) else { return nil }

        let asleepStates: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        ]
        let totalSeconds = samples
            .filter { asleepStates.contains($0.value) }
            .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

        let hours = totalSeconds / 3600.0
        guard hours > 0 else { return nil }
        let score = Int(max(0, min(100, (hours - 4.0) / 3.0 * 100)))
        return SleepResult(hours: hours, score: score)
    }

    // MARK: Generic helpers

    private func fetchLatestQuantity(_ id: HKQuantityTypeIdentifier,
                                     unit: HKUnit,
                                     withinDays: Int) async -> Double? {
        guard let qType = HKQuantityType.quantityType(forIdentifier: id) else { return nil }
        let start = Date().addingTimeInterval(-86400 * Double(withinDays))
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let descriptor = HKSampleQueryDescriptor(
            predicates: [HKSamplePredicate<HKQuantitySample>.quantitySample(
                type: qType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1
        )
        guard let samples = try? await descriptor.result(for: store),
              let sample = samples.first else { return nil }
        return sample.quantity.doubleValue(for: unit)
    }

    private func fetchAverage(_ id: HKQuantityTypeIdentifier,
                               unit: HKUnit,
                               days: Int) async -> Double? {
        guard let qType = HKQuantityType.quantityType(forIdentifier: id) else { return nil }
        let start = Date().addingTimeInterval(-86400 * Double(days))
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        return await withCheckedContinuation { cont in
            let query = HKStatisticsQuery(
                quantityType: qType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, stats, _ in
                cont.resume(returning: stats?.averageQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    // MARK: - Score computation

    private func computeReadiness(hrv: Double?, hrvBaseline: Double?,
                                   rhr: Double?, rhrBaseline: Double?,
                                   sleep: SleepResult?) -> ReadinessData {
        var score = 0
        var vitals: [Vital] = []

        // HRV — up to 40 pts
        if let h = hrv {
            let ratio = (hrvBaseline.map { h / $0 }) ?? 1.0
            let pts: Int
            switch ratio {
            case 1.05...:     pts = 40
            case 0.90..<1.05: pts = 30
            case 0.75..<0.90: pts = 20
            default:          pts = 10
            }
            score += pts
            let (trendStr, trendDir): (String, TrendDir)
            if hrvBaseline != nil {
                let pct = Int(abs(ratio - 1) * 100)
                (trendStr, trendDir) = ratio >= 1
                    ? ("↑ \(pct)% vs 14d", .up)
                    : ("↓ \(pct)% vs 14d", .down)
            } else {
                (trendStr, trendDir) = ("no baseline yet", .flat)
            }
            vitals.append(Vital(label: "HRV", value: "\(Int(h))", unit: "ms",
                                trend: trendStr, trendDir: trendDir))
        } else {
            score += 20 // neutral when no data
        }

        // Sleep — up to 40 pts
        if let s = sleep {
            let pts: Int
            switch s.hours {
            case 7.5...:    pts = 40
            case 7.0..<7.5: pts = 35
            case 6.0..<7.0: pts = 25
            case 5.0..<6.0: pts = 15
            default:        pts = 5
            }
            score += pts
            let hh = Int(s.hours), mm = Int((s.hours - Double(hh)) * 60)
            let dir: TrendDir = s.hours >= 7 ? .up : s.hours >= 6 ? .flat : .down
            vitals.append(Vital(label: "Sleep", value: "\(hh)h \(mm)m", unit: nil,
                                trend: "\(s.score) score", trendDir: dir))
        } else {
            score += 20
        }

        // Resting HR — up to 20 pts
        if let r = rhr {
            let delta = rhrBaseline.map { r - $0 } ?? 0
            let pts: Int
            switch delta {
            case ..<0:    pts = 20
            case 0..<3:   pts = 15
            case 3..<6:   pts = 10
            default:      pts = 5
            }
            score += pts
            let (trendStr, trendDir): (String, TrendDir) = delta <= 0
                ? ("at baseline", .flat)
                : ("+\(Int(delta)) bpm", .down)
            vitals.append(Vital(label: "Resting HR", value: "\(Int(r))", unit: "bpm",
                                trend: trendStr, trendDir: trendDir))
        } else {
            score += 10
        }

        let state: ReadinessState
        switch score {
        case 70...: state = .green
        case 40..<70: state = .yellow
        default: state = .red
        }

        return ReadinessData(
            state: state,
            score: score,
            vitals: vitals,
            reasoning: buildReasoning(state: state, hrv: hrv, hrvBaseline: hrvBaseline,
                                      sleep: sleep, rhr: rhr, rhrBaseline: rhrBaseline)
        )
    }

    private func buildReasoning(state: ReadinessState,
                                 hrv: Double?, hrvBaseline: Double?,
                                 sleep: SleepResult?,
                                 rhr: Double?, rhrBaseline: Double?) -> String {
        switch state {
        case .green:
            return "HRV is strong and sleep was solid. Today's a green light — push as planned."
        case .yellow:
            var reasons: [String] = []
            if let s = sleep, s.hours < 7 { reasons.append("sleep was short (\(String(format: "%.1f", s.hours))h)") }
            if let h = hrv, let b = hrvBaseline, h < b { reasons.append("HRV is slightly suppressed") }
            if let r = rhr, let b = rhrBaseline, r > b + 2 { reasons.append("resting HR is elevated") }
            let detail = reasons.isEmpty ? "some metrics are mixed" : reasons.joined(separator: " and ")
            return "Recovery is moderate — \(detail). We've trimmed intensity to keep you on track without adding stress."
        case .red:
            var reasons: [String] = []
            if let s = sleep, s.hours < 6 { reasons.append("only \(String(format: "%.1f", s.hours))h of sleep") }
            if let h = hrv, let b = hrvBaseline, h < b * 0.85 { reasons.append("HRV is well below baseline") }
            if let r = rhr, let b = rhrBaseline, r > b + 5 { reasons.append("resting HR is high") }
            let detail = reasons.isEmpty ? "multiple metrics are suppressed" : reasons.joined(separator: " and ")
            return "Recovery is suppressed — \(detail). Easy movement today protects next week's sessions."
        }
    }

    // MARK: - Background delivery

    private func enableBackgroundDelivery() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let quantityIDs: [HKQuantityTypeIdentifier] = [.heartRateVariabilitySDNN, .restingHeartRate]
        for id in quantityIDs {
            guard let t = HKQuantityType.quantityType(forIdentifier: id) else { continue }
            try? await store.enableBackgroundDelivery(for: t, frequency: .daily)
        }
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            try? await store.enableBackgroundDelivery(for: sleep, frequency: .daily)
        }
    }

    // MARK: - Notifications

    func requestNotificationPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    // MARK: - 6.1 Morning briefing notification

    func scheduleMorningNotification(data: ReadinessData, hour: Int = 7, enabled: Bool = true) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["healthfit.morning-readiness"])
        guard enabled else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Good morning · Readiness \(data.score)"
        content.body  = "\(data.state.label) — \(data.reasoning)"
        content.sound = .default

        var components = DateComponents()
        components.hour = hour; components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "healthfit.morning-readiness",
                                            content: content, trigger: trigger)
        try? await center.add(request)
    }

    // MARK: - 6.2 Workout reminder notification

    func scheduleWorkoutReminder(
        hour: Int, minute: Int,
        sessionName: String,
        enabled: Bool
    ) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["healthfit.workout-reminder"])
        guard enabled else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        // Fire 30 minutes before the preferred workout time
        let totalMinutes = hour * 60 + minute - 30
        let remindHour   = ((totalMinutes / 60) % 24 + 24) % 24
        let remindMinute = ((totalMinutes % 60) + 60) % 60

        let content = UNMutableNotificationContent()
        content.title = "Workout in 30 minutes"
        content.body  = "\(sessionName) — time to prep and warm up."
        content.sound = .default

        var components = DateComponents()
        components.hour = remindHour; components.minute = remindMinute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "healthfit.workout-reminder",
                                            content: content, trigger: trigger)
        try? await center.add(request)
    }

    // MARK: - 6.3 Nutrition nudge notification

    func scheduleNutritionNudge(sessionKind: String, enabled: Bool) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["healthfit.nutrition-nudge"])
        guard enabled else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let body: String
        switch sessionKind {
        case "strength training":
            body = "It's a lift day — have you hit your protein target yet? Check the Eat tab."
        case "running":
            body = "Running today? Make sure you're loading up on carbs. Tap to check your macros."
        default:
            body = "How's your nutrition tracking today? Check your macro progress."
        }

        let content = UNMutableNotificationContent()
        content.title = "Midday fuel check"
        content.body  = body
        content.sound = .default

        var components = DateComponents()
        components.hour = 12; components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "healthfit.nutrition-nudge",
                                            content: content, trigger: trigger)
        try? await center.add(request)
    }

    // MARK: - Workout history

    func fetchRecentWorkouts(limit: Int = 20) async -> [HKWorkout] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [HKSamplePredicate<HKWorkout>.workout()],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: limit
        )
        return (try? await descriptor.result(for: store)) ?? []
    }

    // MARK: - Live workout metrics

    /// Most recent heart rate sample within the last 5 minutes (for active workout display).
    func fetchCurrentHeartRate() async -> Int? {
        guard HKHealthStore.isHealthDataAvailable(),
              let qType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }
        let start = Date().addingTimeInterval(-300)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let descriptor = HKSampleQueryDescriptor(
            predicates: [HKSamplePredicate<HKQuantitySample>.quantitySample(
                type: qType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1
        )
        guard let samples = try? await descriptor.result(for: store),
              let sample = samples.first else { return nil }
        return Int(sample.quantity.doubleValue(for: .count().unitDivided(by: .minute())))
    }

    // MARK: - Write workout

    func saveWorkout(activityType: HKWorkoutActivityType,
                     start: Date, end: Date,
                     energyKcal: Double? = nil) async throws {
        let config = HKWorkoutConfiguration()
        config.activityType = activityType

        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        try await builder.beginCollection(at: start)

        if let energy = energyKcal {
            let qty = HKQuantity(unit: .kilocalorie(), doubleValue: energy)
            let sample = HKQuantitySample(
                type: HKQuantityType(.activeEnergyBurned),
                quantity: qty,
                start: start, end: end
            )
            try await builder.addSamples([sample])
        }

        try await builder.endCollection(at: end)
        _ = try await builder.finishWorkout()
    }
}

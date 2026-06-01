//
//  AppState.swift
//  Single observable for the prototype. Holds auth, onboarding status, the current
//  user, the active plan, and demo controls (mood toggle, plan view mode).
//
//  When wiring real data:
//   - Replace `readinessSnapshot` with a HealthKit-backed publisher.
//   - Replace `currentPlan` with a server-fetched plan keyed by user.
//   - The email/password auth is local Keychain only (prototype). A real backend
//     would verify credentials server-side.
//

import Foundation
import SwiftUI
import AuthenticationServices
import Security
import SwiftData
import WatchConnectivity
import UserNotifications

// MARK: - WatchConnectivityService

struct WatchWorkoutPayload: Codable {
    let workoutName: String
    let workoutMeta: String
    let exercises: [String]
    let readinessState: String
    let readinessScore: Int
    let readinessLabel: String
    let kcalTarget: Int
    let isAdjusted: Bool
}

@MainActor
final class WatchConnectivityService: NSObject, ObservableObject {

    @Published var isPaired: Bool = false

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ payload: WatchWorkoutPayload) {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isPaired else { return }
        guard let data = try? JSONEncoder().encode(payload),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        try? WCSession.default.updateApplicationContext(dict)
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {
        let paired = session.isPaired
        Task { @MainActor in self.isPaired = paired }
    }
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}

// MARK: - AuthService

@MainActor
final class AuthService: NSObject, ObservableObject {
    @Published var isAuthenticated: Bool = false
    private let service = "com.healthfit.auth"

    override init() {
        super.init()
        restoreSession()
    }

    @discardableResult
    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) -> Bool {
        guard case .success(let auth) = result,
              let cred = auth.credential as? ASAuthorizationAppleIDCredential else { return false }
        keychainSave("userID", value: cred.user)
        keychainSave("method", value: "apple")
        isAuthenticated = true
        return true
    }

    func signUp(email: String, password: String) throws {
        guard !email.isEmpty, password.count >= 8 else { throw AuthError.invalidCredentials }
        keychainSave("userID", value: email)
        keychainSave("method", value: "email")
        keychainSave("email", value: email)
        isAuthenticated = true
    }

    func signIn(email: String, password: String) throws {
        guard let stored = keychainRead("email"), stored == email, !password.isEmpty else {
            throw AuthError.noAccountFound
        }
        isAuthenticated = true
    }

    func signOut() {
        ["userID", "method", "email"].forEach { keychainDelete($0) }
        isAuthenticated = false
    }

    private func restoreSession() {
        guard let id = keychainRead("userID") else { return }
        if keychainRead("method") == "apple" {
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: id) { [weak self] state, _ in
                Task { @MainActor [weak self] in
                    self?.isAuthenticated = state == .authorized
                    if state != .authorized { self?.signOut() }
                }
            }
        } else {
            isAuthenticated = true
        }
    }

    private func keychainSave(_ key: String, value: String) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service,
                                kSecAttrAccount as String: key,
                                kSecValueData as String: value.data(using: .utf8)!]
        SecItemDelete(q as CFDictionary)
        SecItemAdd(q as CFDictionary, nil)
    }

    private func keychainRead(_ key: String) -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service,
                                kSecAttrAccount as String: key,
                                kSecReturnData as String: true,
                                kSecMatchLimit as String: kSecMatchLimitOne]
        var r: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &r) == errSecSuccess,
              let d = r as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    private func keychainDelete(_ key: String) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service,
                                kSecAttrAccount as String: key]
        SecItemDelete(q as CFDictionary)
    }
}

// MARK: - AuthError

enum AuthError: LocalizedError {
    case invalidCredentials, noAccountFound
    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Enter a valid email and a password of 8+ characters."
        case .noAccountFound: return "No account found with that email. Please sign up."
        }
    }
}

// MARK: - AppState

@MainActor
final class AppState: ObservableObject {

    // MARK: Onboarding — backed by UserDefaults so they load synchronously (no UI flash)

    @Published var hasOnboarded: Bool = UserDefaults.standard.bool(forKey: "hasOnboarded")
    @Published var watchConnected: Bool = UserDefaults.standard.bool(forKey: "watchConnected")

    // MARK: Selected goals

    @Published var selectedGoals: Set<FitnessGoal> = []

    // MARK: Training preferences (set during onboarding)

    @Published var trainingType: TrainingType? = nil
    @Published var daysPerWeek: Int = 4
    @Published var prioritizedDiscipline: String? = nil
    @Published var strengthSplit: StrengthSplit? = nil
    @Published var dietaryProfile: DietaryProfile = DietaryProfile(allergies: [], preferences: [], dislikes: [])

    func saveDietaryProfile() { persistToStore() }

    // MARK: Lift history — per-exercise weight records and 1RM predictions

    // MARK: Units preference

    @Published var useMetric: Bool = UserDefaults.standard.object(forKey: "useMetric") as? Bool ?? false

    var weightUnit: String { useMetric ? "kg" : "lbs" }

    /// Step for ±weight buttons in the workout logger (2.5 kg or 5 lbs).
    var weightStep: Double { useMetric ? 2.5 * 2.20462 : 5.0 }

    /// Converts stored lbs to the user's display unit.
    func displayWeight(_ lbs: Double) -> Double { useMetric ? lbs / 2.20462 : lbs }

    /// Converts a value entered in the user's unit back to lbs for storage.
    func storedWeightLbs(_ displayValue: Double) -> Double { useMetric ? displayValue * 2.20462 : displayValue }

    /// Returns a formatted weight string with unit suffix (e.g. "82.5 kg" or "182 lbs").
    func formatWeight(_ lbs: Double) -> String {
        let v = displayWeight(lbs)
        let s = v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
        return "\(s) \(weightUnit)"
    }

    func saveUnitPreference() {
        UserDefaults.standard.set(useMetric, forKey: "useMetric")
    }

    // MARK: Exercise history — per-exercise weight records and 1RM predictions

    @Published var exerciseHistory: [String: [ExerciseRecord]] = [:]

    /// Saves working-set results for one exercise, keeping the last 20 sessions.
    func logExercise(_ name: String, sets: [(weight: Double, reps: Int)]) {
        let working = sets.filter { $0.weight > 0 && $0.reps > 0 }
            .map { LoggedSet(weightLbs: $0.weight, reps: $0.reps) }
        guard !working.isEmpty else { return }
        let record = ExerciseRecord(date: Date(), sets: working)
        let key = normalizeExerciseName(name)
        var history = exerciseHistory[key] ?? []
        history.append(record)
        if history.count > 20 { history.removeFirst(history.count - 20) }
        exerciseHistory[key] = history
        saveExerciseHistory()
    }

    /// Returns the all-time peak estimated 1RM (Epley) for display.
    func estimatedOneRepMax(for name: String) -> Double? {
        let records = exerciseHistory[normalizeExerciseName(name)] ?? []
        let peak = records.map(\.estimatedOneRepMax).max() ?? 0
        return peak > 0 ? peak : nil
    }

    /// Returns a suggested starting weight for the given exercise and rep target,
    /// derived from the most recent session's estimated 1RM and a training percentage.
    /// Result is rounded to the nearest 5 lbs.
    func suggestedWeight(for name: String, targetRepsStr: String) -> Double? {
        let key = normalizeExerciseName(name)
        guard let latest = exerciseHistory[key]?
            .sorted(by: { $0.date > $1.date }).first
        else { return nil }
        let oneRM = latest.estimatedOneRepMax
        guard oneRM > 0 else { return nil }

        let reps = Int(targetRepsStr.filter(\.isNumber)) ?? 8
        let pct: Double
        switch reps {
        case ...3:    pct = 0.90
        case 4...5:   pct = 0.85
        case 6...8:   pct = 0.78
        case 9...12:  pct = 0.72
        default:      pct = 0.65
        }
        let raw = oneRM * pct
        return max(5, (raw / 5).rounded() * 5)
    }

    func loadExerciseHistory() {
        guard let data = UserDefaults.standard.data(forKey: "exerciseHistory"),
              let history = try? JSONDecoder().decode([String: [ExerciseRecord]].self, from: data)
        else { return }
        exerciseHistory = history
    }

    private func saveExerciseHistory() {
        guard let data = try? JSONEncoder().encode(exerciseHistory) else { return }
        UserDefaults.standard.set(data, forKey: "exerciseHistory")
    }

    private func normalizeExerciseName(_ name: String) -> String {
        name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Notification preferences

    @Published var notifyMorning: Bool = UserDefaults.standard.object(forKey: "notifyMorning") as? Bool ?? true
    @Published var notifyWorkout: Bool = UserDefaults.standard.object(forKey: "notifyWorkout") as? Bool ?? true
    @Published var notifyNutrition: Bool = UserDefaults.standard.object(forKey: "notifyNutrition") as? Bool ?? true
    @Published var preferredWorkoutHour: Int = {
        guard UserDefaults.standard.object(forKey: "preferredWorkoutHour") != nil else { return 7 }
        return UserDefaults.standard.integer(forKey: "preferredWorkoutHour")
    }()
    @Published var preferredWorkoutMinute: Int = UserDefaults.standard.integer(forKey: "preferredWorkoutMinute")

    func saveNotificationPreferences() {
        UserDefaults.standard.set(notifyMorning,   forKey: "notifyMorning")
        UserDefaults.standard.set(notifyWorkout,   forKey: "notifyWorkout")
        UserDefaults.standard.set(notifyNutrition, forKey: "notifyNutrition")
        UserDefaults.standard.set(preferredWorkoutHour,   forKey: "preferredWorkoutHour")
        UserDefaults.standard.set(preferredWorkoutMinute, forKey: "preferredWorkoutMinute")
    }

    // MARK: Tab selection — updated by notification deep-links

    @Published var selectedTab: Int = 0

    // MARK: Food log — today's entries, keyed by calendar date in UserDefaults

    @Published var todayFoodLog: [FoodEntry] = []

    private var foodLogKey: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return "foodLog_\(fmt.string(from: Date()))"
    }

    func logFood(_ entry: FoodEntry) {
        todayFoodLog.append(entry)
        saveFoodLog()
        cancelNutritionNudgeIfOnTrack()
        Analytics.foodLogged(source: "unknown")
    }

    private func cancelNutritionNudgeIfOnTrack() {
        let kcalLogged    = todayFoodLog.reduce(0) { $0 + $1.kcal }
        let proteinLogged = todayFoodLog.reduce(0) { $0 + $1.macros.proteinG }
        let adj = adjustedTodayWorkout(readiness: readinessState)
        let kcalPct    = Double(kcalLogged)    / Double(max(adj.kcalTarget, 1))
        let proteinPct = Double(proteinLogged) / Double(max(adj.macros.proteinG, 1))
        if kcalPct > 0.8 || proteinPct > 0.8 {
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: ["healthfit.nutrition-nudge"])
        }
    }

    func removeFoodEntry(id: UUID) {
        todayFoodLog.removeAll { $0.id == id }
        saveFoodLog()
    }

    func updateFoodEntry(_ updated: FoodEntry) {
        guard let idx = todayFoodLog.firstIndex(where: { $0.id == updated.id }) else { return }
        todayFoodLog[idx] = updated
        saveFoodLog()
    }

    func loadFoodLog() {
        guard let data = UserDefaults.standard.data(forKey: foodLogKey),
              let entries = try? JSONDecoder().decode([FoodEntry].self, from: data)
        else { return }
        todayFoodLog = entries
    }

    private func saveFoodLog() {
        guard let data = try? JSONEncoder().encode(todayFoodLog) else { return }
        UserDefaults.standard.set(data, forKey: foodLogKey)
    }

    // MARK: Last plan description — used to re-generate without re-entering text

    @Published var lastPlanDescription: String =
        UserDefaults.standard.string(forKey: "lastPlanDescription") ?? ""

    func saveLastPlanDescription(_ text: String) {
        lastPlanDescription = text
        UserDefaults.standard.set(text, forKey: "lastPlanDescription")
    }

    // MARK: User & plan

    @Published var user: UserProfile = UserProfile(
        name: "", age: 0, sexAtBirth: "Male",
        weightLb: 0, goalWeightLb: 0, description: "")
    @Published var currentPlan: WeekPlan = MockData.hybridWeek

    // MARK: Demo controls

    /// The simulated readiness state, toggled from the Today view's
    /// developer affordance. In production this would come from HealthKit.
    @Published var readinessState: ReadinessState = .green

    /// Plan tab view mode (input vs generated).
    @Published var planMode: PlanMode = .generated

    // MARK: Phase 3 state

    @Published var planLocked: Bool = UserDefaults.standard.bool(forKey: "planLocked")
    @Published var todaySessionAccepted: Bool = false
    @Published var todayForcesOriginalPlan: Bool = false
    @Published var needsNewWeekPlan: Bool = false

    private var weekStartDate: Date {
        get { UserDefaults.standard.object(forKey: "weekStartDate") as? Date ?? .distantPast }
        set { UserDefaults.standard.set(newValue, forKey: "weekStartDate") }
    }

    var readinessSnapshot: ReadinessSnapshot {
        MockData.readiness(for: readinessState)
    }

    // MARK: SwiftData

    private var modelContext: ModelContext?

    func configure(with context: ModelContext) {
        modelContext = context
        loadFoodLog()
        loadFromStore()
        loadExerciseHistory()
    }

    private func loadFromStore() {
        guard let ctx = modelContext else { return }
        let descriptor = FetchDescriptor<PersistedProfile>()
        guard let profile = try? ctx.fetch(descriptor).first else { return }
        user = profile.asUserProfile
        selectedGoals = profile.selectedGoals
        trainingType = profile.trainingType
        daysPerWeek = profile.daysPerWeek
        prioritizedDiscipline = profile.prioritizedDiscipline.isEmpty ? nil : profile.prioritizedDiscipline
        strengthSplit = profile.strengthSplit
        dietaryProfile = profile.dietaryProfile
    }

    func saveUserProfile(_ profile: UserProfile) {
        user = profile
        persistToStore()
    }

    func saveSelectedGoals() {
        persistToStore()
    }

    private func persistToStore() {
        guard let ctx = modelContext else { return }
        let descriptor = FetchDescriptor<PersistedProfile>()
        let existing = try? ctx.fetch(descriptor)
        let record: PersistedProfile
        if let first = existing?.first {
            record = first
        } else {
            record = PersistedProfile()
            ctx.insert(record)
        }
        record.name = user.name
        record.age = user.age
        record.sexAtBirth = user.sexAtBirth
        record.weightLb = user.weightLb
        record.goalWeightLb = user.goalWeightLb
        record.planDescription = user.description
        record.selectedGoalIDs = selectedGoals.map(\.rawValue)
        record.hasOnboarded = hasOnboarded
        record.watchConnected = watchConnected
        record.trainingTypeID = trainingType?.rawValue ?? ""
        record.daysPerWeek = daysPerWeek
        record.prioritizedDiscipline = prioritizedDiscipline ?? ""
        record.strengthSplitID = strengthSplit?.rawValue ?? ""
        record.dietaryAllergies = dietaryProfile.allergies
        record.dietaryPreferences = dietaryProfile.preferences
        record.dietaryDislikes = dietaryProfile.dislikes
        try? ctx.save()
    }

    private func clearStore() {
        guard let ctx = modelContext else { return }
        let descriptor = FetchDescriptor<PersistedProfile>()
        if let profiles = try? ctx.fetch(descriptor) {
            profiles.forEach { ctx.delete($0) }
            try? ctx.save()
        }
    }

    // MARK: - Actions

    func completeOnboarding() {
        hasOnboarded = true
        UserDefaults.standard.set(true, forKey: "hasOnboarded")
        persistToStore()
        Analytics.onboardingCompleted(
            trainingType: trainingType?.rawValue,
            strengthSplit: strengthSplit?.rawValue
        )
    }

    func resetOnboarding() {
        hasOnboarded = false
        watchConnected = false
        selectedGoals = []
        trainingType = nil
        daysPerWeek = 4
        prioritizedDiscipline = nil
        strengthSplit = nil
        dietaryProfile = DietaryProfile(allergies: [], preferences: [], dislikes: [])
        todayFoodLog = []
        UserDefaults.standard.removeObject(forKey: foodLogKey)
        lastPlanDescription = ""
        UserDefaults.standard.removeObject(forKey: "lastPlanDescription")
        notifyMorning = true;   UserDefaults.standard.removeObject(forKey: "notifyMorning")
        notifyWorkout = true;   UserDefaults.standard.removeObject(forKey: "notifyWorkout")
        notifyNutrition = true; UserDefaults.standard.removeObject(forKey: "notifyNutrition")
        preferredWorkoutHour = 7;   UserDefaults.standard.removeObject(forKey: "preferredWorkoutHour")
        preferredWorkoutMinute = 0; UserDefaults.standard.removeObject(forKey: "preferredWorkoutMinute")
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        exerciseHistory = [:]
        UserDefaults.standard.removeObject(forKey: "exerciseHistory")
        useMetric = false
        UserDefaults.standard.removeObject(forKey: "useMetric")
        user = UserProfile(name: "", age: 0, sexAtBirth: "Male",
                           weightLb: 0, goalWeightLb: 0, description: "")
        planLocked = false
        todaySessionAccepted = false
        todayForcesOriginalPlan = false
        needsNewWeekPlan = false
        currentPlan = MockData.hybridWeek
        UserDefaults.standard.set(false, forKey: "hasOnboarded")
        UserDefaults.standard.set(false, forKey: "watchConnected")
        UserDefaults.standard.set(false, forKey: "planLocked")
        UserDefaults.standard.removeObject(forKey: "weekStartDate")
        clearStore()
    }

    func setWatchConnected(_ connected: Bool) {
        watchConnected = connected
        UserDefaults.standard.set(connected, forKey: "watchConnected")
        persistToStore()
    }

    /// Falls back to a split-appropriate mock plan (used when FM is unavailable).
    func regeneratePlan() {
        currentPlan = MockData.plan(trainingType: trainingType, strengthSplit: strengthSplit)
        planMode = .generated
        Analytics.planGenerated(source: "mock_fallback")
    }

    /// Converts a Foundation Models GeneratedPlan into a WeekPlan and applies it.
    func applyGeneratedPlan(_ generated: GeneratedPlan) {
        Analytics.planGenerated(source: "foundation_models")
        let calendar = Calendar.current
        let today = Date()
        // Anchor to the Monday of the current week
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!

        let days: [PlanDay] = generated.days.prefix(7).enumerated().map { offset, genDay in
            let date = calendar.date(byAdding: .day, value: offset, to: monday)!
            let dayNumber = calendar.component(.day, from: date)
            let isToday = calendar.isDateInToday(date)

            let sessions: [PlanSession] = genDay.sessions.map { s in
                let kind: SessionKind = switch s.kind.lowercased() {
                    case "lift":  .lift
                    case "run":   .run
                    case "yoga":  .yoga
                    default:      .rest
                }
                return PlanSession(kind: kind, name: s.name, durationMin: s.durationMin)
            }
            return PlanDay(weekday: genDay.weekday, dayNumber: dayNumber,
                           tag: genDay.tag, isToday: isToday, sessions: sessions)
        }

        currentPlan = WeekPlan(
            weekIndex: currentPlan.weekIndex,
            totalWeeks: currentPlan.totalWeeks,
            phase: currentPlan.phase,
            days: days,
            summary: generated.summary,
            approach: generated.approach
        )
        planMode = .generated
        planLocked = false
    }

    // MARK: - 3.3 Readiness-driven adjustment

    struct AdjustedWorkout {
        let title: String
        let name: String
        let meta: String
        let chips: [String]
        let tag: String          // "As planned" | "Adjusted"
        let kcalTarget: Int
        let macros: Macros
        let macroTag: String
    }

    func adjustedTodayWorkout(readiness: ReadinessState) -> AdjustedWorkout {
        let weekLabel = "Today · Week \(currentPlan.weekIndex) of \(currentPlan.totalWeeks)"
        let todayDay = currentPlan.days.first(where: { $0.isToday })
        let main = todayDay?.sessions.first(where: { $0.kind != .yoga && $0.kind != .rest })
                ?? todayDay?.sessions.first

        guard let session = main else {
            let mock = MockData.readiness(for: readiness)
            return AdjustedWorkout(title: mock.workoutTitle, name: mock.workoutName,
                                   meta: mock.workoutMeta, chips: mock.workoutChips,
                                   tag: mock.workoutTag, kcalTarget: mock.kcalTarget,
                                   macros: mock.macros, macroTag: mock.macroTag)
        }

        switch readiness {
        case .green:
            let (kcal, macros, macroTag) = macroTargets(for: session.kind, readiness: .green)
            return AdjustedWorkout(
                title: weekLabel,
                name: session.name,
                meta: "~\(session.durationMin) min · \(kindLabel(session.kind)) · Moderate-high",
                chips: sessionChips(session: session, readiness: .green),
                tag: "As planned",
                kcalTarget: kcal, macros: macros, macroTag: macroTag
            )
        case .yellow:
            let reduced = session.durationMin * 4 / 5
            let (kcal, macros, macroTag) = macroTargets(for: session.kind, readiness: .yellow)
            return AdjustedWorkout(
                title: weekLabel,
                name: session.name + ", lighter",
                meta: "~\(reduced) min · \(kindLabel(session.kind)) · Moderate",
                chips: sessionChips(session: session, readiness: .yellow),
                tag: "Adjusted",
                kcalTarget: kcal, macros: macros, macroTag: macroTag
            )
        case .red:
            let (kcal, macros, macroTag) = macroTargets(for: session.kind, readiness: .red)
            return AdjustedWorkout(
                title: weekLabel,
                name: "Easy Z2 walk + mobility",
                meta: "~30 min · Recovery",
                chips: ["20 min easy walk", "~110 bpm cap", "10 min mobility"],
                tag: "Adjusted",
                kcalTarget: kcal, macros: macros, macroTag: macroTag
            )
        }
    }

    private func kindLabel(_ kind: SessionKind) -> String {
        switch kind {
        case .lift: return "Lift"
        case .run:  return "Run"
        case .yoga: return "Yoga"
        case .rest: return "Recovery"
        }
    }

    private func sessionChips(session: PlanSession, readiness: ReadinessState) -> [String] {
        let n = session.name.lowercased()
        switch readiness {
        case .green:
            switch session.kind {
            case .lift:
                return liftChips(sessionName: n)
            case .run where n.contains("tempo"):
                return ["10 min warm-up", "4×5 min tempo", "2 min recovery walk", "Cool-down"]
            case .run:
                return ["Easy conversational pace", "Zone 2 effort", "Heart rate < 140 bpm"]
            case .yoga:
                return [session.name, "Focus on breath", "Hold 45–60 s per pose"]
            case .rest:
                return ["Light walk", "Mobility work", "Foam rolling"]
            }
        case .yellow:
            switch session.kind {
            case .lift:
                let reduced = liftChips(sessionName: n)
                    .compactMap { $0.contains("×") ? $0 + " (−20% load)" : nil }
                return reduced.isEmpty
                    ? ["\(session.name) at reduced load", "Stop 4–5 RIR", "Skip accessories"]
                    : reduced
            case .run:
                return ["Easy Zone 2 only", "Cap effort at 7/10", "Shorten if needed"]
            case .yoga:
                return [session.name, "Gentle pace today"]
            case .rest:
                return ["Light walk only", "Mobility work"]
            }
        case .red:
            return ["20 min easy walk", "~110 bpm cap", "10 min mobility"]
        }
    }

    /// Returns exercise chips in "Name sets×reps" format so WorkoutSessionView
    /// can parse them into trackable exercise cards. Respects the user's chosen split.
    private func liftChips(sessionName n: String) -> [String] {
        switch strengthSplit {

        case .fullBody:
            return [
                "Back squat 3×8",
                "Bench press 3×8",
                "Bent row 3×8",
                "RDL 3×10",
                "OHP 3×10",
            ]

        case .ppl:
            let isPush = n.contains("push") || n.contains("bench") || n.contains("press") || n.contains("ohp")
            let isPull = n.contains("pull") || n.contains("row") || n.contains("curl") || n.contains("back")
            if isPush {
                return [
                    "Bench press 4×6",
                    "OHP 3×8",
                    "Dumbbell lateral raise 3×12",
                    "Tricep pushdown 3×12",
                ]
            } else if isPull {
                return [
                    "Pull-ups 3×AMRAP",
                    "Bent row 4×6",
                    "Lat pulldown 3×10",
                    "Barbell curl 3×12",
                ]
            } else {
                // Lower day (default for "squat", "rdl", "leg", or unrecognised PPL day)
                return [
                    "Back squat 4×6",
                    "RDL 3×8",
                    "Walking lunge 3×10",
                    "Leg press 3×12",
                    "Calf raise 3×15",
                ]
            }

        case .upperLower:
            let isUpper = n.contains("upper") || n.contains("press") || n.contains("bench") ||
                          n.contains("row")   || n.contains("pull")
            if isUpper {
                return [
                    "Bench press 4×6",
                    "Bent row 3×8",
                    "OHP 3×8",
                    "Pull-ups 3×AMRAP",
                ]
            } else {
                return [
                    "Back squat 4×6",
                    "RDL 3×8",
                    "Walking lunge 3×10",
                    "Calf raise 3×12",
                ]
            }

        case nil:
            // No split set — fall back to name-based heuristic
            if n.contains("lower") || n.contains("leg") || n.contains("squat") || n.contains("rdl") {
                return ["Back squat 4×6", "RDL 3×8", "Walking lunge 3×10", "Calf raise 3×12"]
            } else if n.contains("upper") {
                return ["Bench press 4×6", "Bent row 3×8", "OHP 3×8", "Pull-ups 3×AMRAP"]
            } else if n.contains("push") {
                return ["Bench press 4×6", "OHP 3×8", "Lateral raise 3×12", "Tricep pushdown 3×12"]
            } else if n.contains("pull") {
                return ["Pull-ups 3×AMRAP", "Bent row 4×6", "Lat pulldown 3×10", "Barbell curl 3×12"]
            } else {
                return ["Back squat 3×8", "Bench press 3×8", "Bent row 3×8", "OHP 3×8"]
            }
        }
    }

    private func macroTargets(for kind: SessionKind, readiness: ReadinessState) -> (Int, Macros, String) {
        switch readiness {
        case .green:
            switch kind {
            case .lift: return (2180, Macros(carbsG: 220, proteinG: 175, fatG: 75), "Lift day · +protein")
            case .run:  return (2200, Macros(carbsG: 240, proteinG: 165, fatG: 70), "Run day · +carbs")
            case .yoga: return (1950, Macros(carbsG: 195, proteinG: 155, fatG: 72), "Light day")
            case .rest: return (1800, Macros(carbsG: 160, proteinG: 160, fatG: 70), "Rest day · −carbs")
            }
        case .yellow:
            return (2080, Macros(carbsG: 200, proteinG: 170, fatG: 75), "Moderate day")
        case .red:
            return (1920, Macros(carbsG: 160, proteinG: 175, fatG: 75), "Recovery · −carbs")
        }
    }

    // MARK: - 3.4 Plan actions

    func lockPlan() {
        planLocked = true
        UserDefaults.standard.set(true, forKey: "planLocked")
    }

    func acceptTodaySession() {
        todaySessionAccepted = true
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["healthfit.workout-reminder"])
    }

    func forceOriginalPlan() {
        todayForcesOriginalPlan = true
    }

    func setFullRestDay() {
        guard let idx = currentPlan.days.firstIndex(where: { $0.isToday }) else { return }
        currentPlan.days[idx] = PlanDay(
            weekday: currentPlan.days[idx].weekday,
            dayNumber: currentPlan.days[idx].dayNumber,
            tag: "Full rest",
            isToday: true,
            sessions: [PlanSession(kind: .rest, name: "Full rest day", durationMin: 0)]
        )
        todaySessionAccepted = true
    }

    func moveTodayToTomorrow() {
        guard let todayIdx = currentPlan.days.firstIndex(where: { $0.isToday }),
              todayIdx + 1 < currentPlan.days.count else { return }
        let tomorrowIdx = todayIdx + 1

        // Swap sessions and tags; dates/weekdays stay anchored to their day
        let todaySessions = currentPlan.days[todayIdx].sessions
        let todayTag = currentPlan.days[todayIdx].tag
        let tmrwSessions = currentPlan.days[tomorrowIdx].sessions
        let tmrwTag = currentPlan.days[tomorrowIdx].tag

        currentPlan.days[todayIdx] = PlanDay(
            weekday: currentPlan.days[todayIdx].weekday,
            dayNumber: currentPlan.days[todayIdx].dayNumber,
            tag: tmrwTag,
            isToday: true,
            sessions: tmrwSessions
        )
        currentPlan.days[tomorrowIdx] = PlanDay(
            weekday: currentPlan.days[tomorrowIdx].weekday,
            dayNumber: currentPlan.days[tomorrowIdx].dayNumber,
            tag: todayTag,
            isToday: false,
            sessions: todaySessions
        )
        todaySessionAccepted = false
    }

    func swapDays(a: Int, b: Int) {
        guard a != b,
              a < currentPlan.days.count,
              b < currentPlan.days.count else { return }
        let aSessions = currentPlan.days[a].sessions
        let aTag = currentPlan.days[a].tag
        currentPlan.days[a] = PlanDay(
            weekday: currentPlan.days[a].weekday,
            dayNumber: currentPlan.days[a].dayNumber,
            tag: currentPlan.days[b].tag,
            isToday: currentPlan.days[a].isToday,
            sessions: currentPlan.days[b].sessions
        )
        currentPlan.days[b] = PlanDay(
            weekday: currentPlan.days[b].weekday,
            dayNumber: currentPlan.days[b].dayNumber,
            tag: aTag,
            isToday: currentPlan.days[b].isToday,
            sessions: aSessions
        )
    }

    // MARK: - 3.5 Week progression

    func advanceWeekIfNeeded() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysFromMon = (weekday + 5) % 7
        guard let thisMonday = cal.date(byAdding: .day, value: -daysFromMon, to: today) else { return }

        guard thisMonday > weekStartDate else { return }
        weekStartDate = thisMonday

        // Reset daily state for the new week
        todaySessionAccepted = false
        todayForcesOriginalPlan = false
        planLocked = false
        UserDefaults.standard.set(false, forKey: "planLocked")

        guard currentPlan.weekIndex < currentPlan.totalWeeks else {
            needsNewWeekPlan = false  // block complete
            return
        }

        let nextIndex = currentPlan.weekIndex + 1
        let progress = Double(nextIndex) / Double(currentPlan.totalWeeks)
        let nextPhase: String
        switch progress {
        case ..<0.34: nextPhase = "Base"
        case ..<0.67: nextPhase = "Build"
        case ..<0.84: nextPhase = "Peak"
        default:      nextPhase = "Taper"
        }

        // Placeholder plan — FM will generate the real one from PlanInputView
        currentPlan = WeekPlan(
            weekIndex: nextIndex,
            totalWeeks: currentPlan.totalWeeks,
            phase: nextPhase,
            days: currentPlan.days,
            summary: "Week \(nextIndex) — tap Generate to build your personalised plan.",
            approach: currentPlan.approach
        )
        needsNewWeekPlan = true
    }

    // MARK: - Watch sync

    let watchService = WatchConnectivityService()

    func syncToWatch(readiness: ReadinessState, score: Int) {
        let adj = adjustedTodayWorkout(readiness: readiness)
        let payload = WatchWorkoutPayload(
            workoutName: adj.name,
            workoutMeta: adj.meta,
            exercises: adj.chips,
            readinessState: readiness.rawValue,
            readinessScore: score,
            readinessLabel: readiness.label,
            kcalTarget: adj.kcalTarget,
            isAdjusted: adj.tag == "Adjusted"
        )
        watchService.send(payload)
    }

    // MARK: - 7.3 Data export

    struct HealthFitExport: Codable {
        struct TrainingPrefs: Codable {
            let type: String?
            let strengthSplit: String?
            let daysPerWeek: Int
            let prioritizedDiscipline: String?
        }
        let exportedAt: String          // ISO 8601
        let profile: UserProfile
        let trainingPreferences: TrainingPrefs
        let dietaryProfile: DietaryProfile
        let todayFoodLog: [FoodEntry]
        let exerciseHistory: [String: [ExerciseRecord]]
    }

    func exportData() -> Data? {
        let fmt = ISO8601DateFormatter()
        let payload = HealthFitExport(
            exportedAt: fmt.string(from: Date()),
            profile: user,
            trainingPreferences: .init(
                type: trainingType?.rawValue,
                strengthSplit: strengthSplit?.rawValue,
                daysPerWeek: daysPerWeek,
                prioritizedDiscipline: prioritizedDiscipline
            ),
            dietaryProfile: dietaryProfile,
            todayFoodLog: todayFoodLog,
            exerciseHistory: exerciseHistory
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(payload)
    }
}

// MARK: - PlanMode

enum PlanMode: String, CaseIterable, Identifiable {
    case input = "Input"
    case generated = "Generated"
    var id: String { rawValue }
}

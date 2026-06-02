//
//  TodayView.swift
//  Morning briefing. Vitals, score, and reasoning come from ReadinessService
//  (live HealthKit). Workout and nutrition fields are still plan-driven mock
//  data — Phase 3 and 4 will replace those respectively.
//

import SwiftUI
import HealthKit

struct TodayView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var readinessService: ReadinessService
    @EnvironmentObject var fmService: FoundationModelService
    @State private var showSettings = false
    @State private var showWorkoutSession = false

    // 5.3 — proactive nudges
    @State private var enhancedReasoning: String? = nil
    @State private var coachInsight: String? = nil
    @State private var weekSummaryText: String? = nil

    // Live HealthKit data is suppressed when user taps "Keep original".
    private var activeReadiness: ReadinessState {
        if appState.todayForcesOriginalPlan { return .green }
        return readinessService.latestData?.state ?? appState.readinessState
    }

    private var snapshot: ReadinessSnapshot {
        let readiness = activeReadiness
        let adj = appState.adjustedTodayWorkout(readiness: readiness)
        let liveData = appState.todayForcesOriginalPlan ? nil : readinessService.latestData
        let mock = MockData.readiness(for: readiness)

        return ReadinessSnapshot(
            state: readiness,
            score: liveData?.score ?? mock.score,
            vitals: liveData?.vitals ?? mock.vitals,
            workoutTitle: adj.title,
            workoutName: adj.name,
            workoutMeta: adj.meta,
            workoutChips: adj.chips,
            workoutTag: adj.tag,
            reasoning: liveData?.reasoning ?? mock.reasoning,
            kcalTarget: adj.kcalTarget,
            macros: adj.macros,
            macroTag: adj.macroTag
        )
    }

    private var isLiveData: Bool { !appState.todayForcesOriginalPlan && readinessService.latestData != nil }
    private var accent: Color { Theme.accent(for: snapshot.state) }
    private var accentSoft: Color { Theme.accentSoft(for: snapshot.state) }

    private var todayLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE · MMMM d"
        return fmt.string(from: Date.now)
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    primaryGoalChip
                    if appState.needsNewWeekPlan { weekSummaryCard }
                    coachInsightCard
                    watchDataBanner
                    readinessCard
                    if !appState.todaySessionAccepted {
                        workoutCard
                        reasoningCard
                    }
                    actionsRow
                    nutritionCard
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }

            // Loading overlay when readiness is being fetched
            if readinessService.isLoading {
                VStack(spacing: 10) {
                    ProgressView().tint(Theme.green)
                    Text("Reading health data…")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.bg.opacity(0.7))
            }
        }
        .toolbar { toolbarItems }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(authService)
        }
        .task {
            if appState.watchConnected {
                await readinessService.fetchReadiness()
            }
            // Push today's workout to the Watch after any readiness update.
            appState.syncToWatch(
                readiness: activeReadiness,
                score: readinessService.latestData?.score ?? 0,
                vitals: readinessService.latestData?.vitals ?? []
            )

            // MARK: Phase 6 — schedule notifications

            // 6.1 Morning briefing (uses fresh readiness data if available)
            if let data = readinessService.latestData {
                await readinessService.scheduleMorningNotification(
                    data: data, hour: 7, enabled: appState.notifyMorning
                )
            }

            // 6.2 Workout reminder — 30 min before preferred time
            let todaySession = appState.currentPlan.days
                .first(where: { $0.isToday })?
                .sessions.first(where: { $0.kind == .lift || $0.kind == .run })
            await readinessService.scheduleWorkoutReminder(
                hour: appState.preferredWorkoutHour,
                minute: appState.preferredWorkoutMinute,
                sessionName: todaySession?.name ?? "Today's workout",
                enabled: appState.notifyWorkout && !appState.todaySessionAccepted
            )

            // 6.3 Nutrition nudge at noon
            let todayKind = todaySession?.kind
            let sessionKind = todayKind == .lift ? "strength training"
                            : todayKind == .run  ? "running" : "rest"
            await readinessService.scheduleNutritionNudge(
                sessionKind: sessionKind,
                enabled: appState.notifyNutrition
            )

            guard fmService.isAvailable else { return }

            // Foundation Models cannot handle concurrent sessions — run sequentially.
            let name = appState.user.name.isEmpty ? "there" : appState.user.name

            // 1. Personalise the morning briefing.
            enhancedReasoning = await fmService.enhanceReadinessReasoning(
                snapshot.reasoning, userName: name, state: activeReadiness
            )

            // 2. Daily coach insight — vitals-aware check-in.
            let insight = await fmService.generateCoachInsight(
                userName: name,
                state: activeReadiness,
                vitals: snapshot.vitals,
                workoutSessionName: snapshot.workoutName
            )
            if !insight.isEmpty { coachInsight = insight }

            // 3. End-of-week summary (only when the week has just rolled over).
            if appState.needsNewWeekPlan {
                weekSummaryText = await fmService.generateWeekSummary(
                    weekIndex: max(1, appState.currentPlan.weekIndex - 1),
                    totalWeeks: appState.currentPlan.totalWeeks,
                    phase: appState.currentPlan.phase,
                    userName: name
                )
            }
        }
        .sheet(isPresented: $showWorkoutSession) {
            if let todayDay = appState.currentPlan.days.first(where: { $0.isToday }),
               let session = todayDay.sessions.first(where: { $0.kind != .rest }) ?? todayDay.sessions.first {
                WorkoutSessionView(
                    session: session,
                    readiness: activeReadiness,
                    chips: snapshot.workoutChips
                )
                .environmentObject(appState)
                .environmentObject(readinessService)
            }
        }
    }

    // MARK: Watch data warning

    @ViewBuilder
    private var watchDataBanner: some View {
        if !appState.watchConnected {
            watchWarningRow(
                icon: "applewatch",
                message: "Connect Apple Watch to get live readiness data. Go to Settings › Health to grant access."
            )
        } else if readinessService.latestData == nil && !readinessService.isLoading {
            watchWarningRow(
                icon: "exclamationmark.triangle",
                message: "No Watch data yet — wear your Apple Watch overnight and reopen the app."
            )
        }
    }

    private func watchWarningRow(icon: String, message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.yellow)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.yellow.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.yellow.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(todayLabel).eyebrow()
            Text("Morning, \(appState.user.name.isEmpty ? "there" : appState.user.name)")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Theme.text)
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    // MARK: Primary goal chip — surfaces the user's "why" near the top

    @ViewBuilder
    private var primaryGoalChip: some View {
        if let label = primaryGoalChipLabel {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.card2)
            .clipShape(Capsule())
        }
    }

    /// Returns nil when no primary goal has been set so the chip is hidden
    /// for legacy users who haven't been through the new onboarding.
    private var primaryGoalChipLabel: String? {
        guard let goal = appState.primaryGoal else { return nil }
        switch goal {
        case .eventTraining:
            let name = appState.targetEventName.trimmingCharacters(in: .whitespaces)
            let display = name.isEmpty ? "Event training" : name
            guard let date = appState.targetEventDate else {
                return "\(goal.emoji) \(display)"
            }
            let weeks = max(0, Calendar.current.dateComponents([.weekOfYear], from: Date(), to: date).weekOfYear ?? 0)
            return "\(goal.emoji) \(display) · \(weeks) weeks out"
        case .longevity:
            return "\(goal.emoji) Health-span focus"
        case .vo2max:
            return "\(goal.emoji) VO2 max focus"
        case .buildMuscle:
            return "\(goal.emoji) Building muscle"
        case .generalFitness:
            return "\(goal.emoji) General fitness"
        }
    }

    // MARK: Readiness hero

    private var readinessCard: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [accentSoft, .clear],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Readiness").eyebrow()
                    Spacer()
                    if !isLiveData {
                        Text("DEMO").eyebrow().foregroundColor(Theme.yellow)
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(snapshot.score)")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(accent)
                        .kerning(-1.5)
                    Text(snapshot.state.label)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(accent)
                }
                Text(snapshot.state.verdict)
                    .font(.system(size: 15))
                    .foregroundColor(Theme.text)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !snapshot.vitals.isEmpty {
                    Rectangle()
                        .fill(Theme.separator)
                        .frame(height: 1)
                        .padding(.top, 4)
                    HStack(spacing: 0) {
                        ForEach(Array(snapshot.vitals.enumerated()), id: \.element.id) { i, vital in
                            if i > 0 {
                                Rectangle()
                                    .fill(Theme.separator)
                                    .frame(width: 1, height: 44)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(vital.label)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(Theme.textMuted)
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                                HStack(alignment: .firstTextBaseline, spacing: 3) {
                                    Text(vital.value)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Theme.text)
                                    if let unit = vital.unit {
                                        Text(unit)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(Theme.textMuted)
                                    }
                                }
                                Text(vital.trend)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(vital.trendDir == .up ? Theme.green
                                                   : vital.trendDir == .down ? Theme.red
                                                   : Theme.textMuted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(22)
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: Workout card

    private var workoutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(snapshot.workoutTitle).eyebrow()
                Spacer()
                StatusTag(text: snapshot.workoutTag, tint: accent)
            }
            Text(snapshot.workoutName)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Theme.text)
            Text(snapshot.workoutMeta)
                .font(.system(size: 14))
                .foregroundColor(Theme.textMuted)
            FlowLayout(spacing: 6) {
                ForEach(snapshot.workoutChips, id: \.self) { Chip(text: $0) }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: Reasoning

    private var reasoningCard: some View {
        ReasoningCallout(
            title: snapshot.state == .green ? "Why this session." : "Why we adjusted.",
            message: enhancedReasoning ?? snapshot.reasoning,
            tint: accent
        )
    }

    // MARK: Actions

    private var actionsRow: some View {
        VStack(spacing: 8) {
            if appState.todaySessionAccepted, let summary = appState.completedWorkoutSummary {
                completedWorkoutSummaryCard(summary: summary)
            } else if appState.todaySessionAccepted {
                PrimaryButton(title: "Workout logged ✓", tint: Theme.green, action: {})
                    .disabled(true)
            } else {
                PrimaryButton(
                    title: snapshot.state == .green ? "Start workout"
                         : snapshot.state == .yellow ? "Accept adjusted plan"
                         : "Accept easy day",
                    tint: accent
                ) {
                    showWorkoutSession = true
                }
                HStack(spacing: 8) {
                    if snapshot.state == .red {
                        SecondaryButton(title: "Full rest day") {
                            appState.setFullRestDay()
                        }
                    } else {
                        SecondaryButton(title: "Modify", action: {})
                    }

                    if snapshot.state == .green {
                        SecondaryButton(title: "Move to tomorrow") {
                            appState.moveTodayToTomorrow()
                        }
                    } else {
                        SecondaryButton(
                            title: appState.todayForcesOriginalPlan ? "Restore adjustment" : "Keep original"
                        ) {
                            appState.todayForcesOriginalPlan.toggle()
                        }
                    }
                }
            }
        }
    }

    // MARK: Completed workout summary card

    private func completedWorkoutSummaryCard(summary: CompletedWorkoutSummary) -> some View {
        let mins = summary.elapsedSeconds / 60
        let secs = summary.elapsedSeconds % 60
        let durationStr = String(format: "%d:%02d", mins, secs)

        return VStack(alignment: .leading, spacing: 14) {

            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Theme.green.opacity(0.15))
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(Theme.green)
                }
                .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.sessionName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.text)
                        .lineLimit(1)
                    Text("Completed")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.green)
                }
                Spacer()
            }

            // Stats row
            HStack(spacing: 0) {
                summaryStatPill(icon: "timer", color: Theme.blue, value: durationStr, label: "Duration")
                if let hr = summary.avgHR {
                    Rectangle().fill(Theme.separator).frame(width: 1, height: 36)
                    summaryStatPill(icon: "heart.fill", color: Theme.red, value: "\(hr)", label: "Avg BPM")
                }
                Rectangle().fill(Theme.separator).frame(width: 1, height: 36)
                summaryStatPill(icon: "flame.fill", color: Theme.orange, value: "\(summary.kcalBurned)", label: "Cal")
            }
            .background(Theme.card2)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Exercise highlights (strength sessions only)
            let doneExercises = summary.exercises.filter { !$0.wasSkipped && !$0.loggedSets.isEmpty }
            if !doneExercises.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Session highlights")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(Theme.textGhost)
                        .tracking(1)

                    ForEach(doneExercises, id: \.name) { ex in
                        workingSetsHighlight(ex: ex)
                    }
                }
            }
        }
        .padding(18)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func summaryStatPill(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(Theme.text)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.textGhost)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func workingSetsHighlight(ex: CompletedExerciseSummary) -> some View {
        let working = ex.loggedSets.filter { !$0.isWarmup }
        let weights = working.map { appState.displayWeight($0.weightLbs) }
        let unit = appState.weightUnit

        let weightStr: String = {
            guard !weights.isEmpty else { return "—" }
            let formatted = weights.map { v -> String in
                v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
            }
            if Set(formatted).count == 1 { return "\(formatted[0]) \(unit)" }
            return formatted.joined(separator: "/") + " \(unit)"
        }()

        let repStr: String = {
            let reps = working.map(\.reps)
            guard !reps.isEmpty else { return "" }
            if Set(reps).count == 1 { return "× \(reps[0]) reps" }
            return "× " + reps.map { "\($0)" }.joined(separator: "/") + " reps"
        }()

        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(Theme.green.opacity(0.6))
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(ex.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.text)
                HStack(spacing: 6) {
                    Text("\(working.count) set\(working.count == 1 ? "" : "s")")
                        .foregroundColor(Theme.textMuted)
                    if !weightStr.isEmpty {
                        Text("·").foregroundColor(Theme.textGhost)
                        Text(weightStr).foregroundColor(Theme.textMuted)
                    }
                    if !repStr.isEmpty {
                        Text(repStr).foregroundColor(Theme.textMuted)
                    }
                }
                .font(.system(size: 12))
                if let rm = ex.bestOneRM {
                    let displayRM = appState.displayWeight(rm)
                    let rmStr = displayRM.truncatingRemainder(dividingBy: 1) == 0
                        ? "\(Int(displayRM.rounded()))" : String(format: "%.1f", displayRM)
                    Text("Est. 1RM \(rmStr) \(unit)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.blue)
                }
            }
        }
    }

    // MARK: Nutrition

    private var nutritionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today's fuel").eyebrow()
                Spacer()
                Text(snapshot.macroTag)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(accent)
                    .textCase(.uppercase)
                    .tracking(0.6)
            }
            HStack(spacing: 18) {
                MacroBlock(value: "\(snapshot.kcalTarget)", label: "kcal target")
                MacroBlock(value: "\(snapshot.macros.carbsG)g", label: "Carbs")
                MacroBlock(value: "\(snapshot.macros.proteinG)g", label: "Protein")
                MacroBlock(value: "\(snapshot.macros.fatG)g", label: "Fat")
            }
        }
        .padding(18)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.top, 6)
    }

    // MARK: Coach insight (5.3)

    private var coachInsightFallback: String {
        let hrv   = snapshot.vitals.first(where: { $0.label == "HRV" })
        let sleep = snapshot.vitals.first(where: { $0.label == "Sleep" })
        let rhr   = snapshot.vitals.first(where: { $0.label == "Resting HR" })

        switch snapshot.state {
        case .red:
            if hrv?.trendDir == .down {
                return "HRV is trending down (\(hrv?.trend ?? "below baseline")), which is a signal your nervous system is under extra load — stress, hard training, or poor sleep can all cause this. Today is a perfect day to prioritise rest and light movement. You'll recover faster by working with your body, not against it."
            } else if sleep?.trendDir == .down {
                return "Sleep was shorter than ideal last night (\(sleep?.value ?? "reduced")), and your body is feeling the impact. Focus on recovery today — eat well, reduce stress where you can, and aim for an earlier bedtime. Rest is as important as any workout."
            }
            return "Your body is asking for a recovery day today, and that's completely normal — it's part of the process. Keep movement gentle, stay hydrated, and let your system recharge. You'll come back stronger."
        case .yellow:
            if hrv?.trendDir == .down, let rhrVital = rhr, rhrVital.trendDir == .down {
                return "HRV is slightly below your norm and resting HR is nudging up — classic signs your body is adapting to recent training load. We've trimmed today's intensity accordingly. Consistency at a slightly reduced effort still builds fitness and keeps you healthy long-term."
            } else if hrv?.trendDir == .down {
                return "HRV is a touch below baseline (\(hrv?.trend ?? "slightly low")), suggesting your body is still catching up from recent effort. Today's plan is dialled back to match — give it your best at the adjusted load and trust the process."
            }
            return "Metrics are slightly below your personal norm today, so intensity is dialled back a notch. That's smart, not soft — consistent moderate effort beats boom-and-bust every time. Keep showing up."
        case .green:
            if hrv?.trendDir == .up {
                return "HRV is trending up (\(hrv?.trend ?? "above baseline")) — a reliable sign your training is landing well and recovery is on track. Sleep looks solid and resting HR is healthy. Your body is primed today; go make the most of it."
            } else if let rhrVital = rhr, rhrVital.trendDir == .flat || rhrVital.trendDir == .up {
                return "Your readiness metrics are in a great range today — HRV, sleep, and resting HR are all where you want them. This is what consistent training and recovery looks like. Trust your preparation and attack today's session with confidence."
            }
            return "Everything is looking solid today. Your metrics are in a healthy range and your body is ready to perform. Focus, commit to the work, and enjoy the session."
        }
    }

    private var coachInsightCard: some View {
        ReasoningCallout(
            title: "Coach.",
            message: coachInsight ?? coachInsightFallback,
            tint: Theme.purple,
            iconText: "C"
        )
    }

    // MARK: Week summary (5.3)

    private var weekSummaryCard: some View {
        let completedWeek = max(1, appState.currentPlan.weekIndex - 1)
        let nextWeek      = appState.currentPlan.weekIndex
        let total         = appState.currentPlan.totalWeeks
        let fallback      = "Week \(completedWeek) of \(total) is in the books. Ready to build on it — generate your Week \(nextWeek) plan below."

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Week \(completedWeek) complete").eyebrow()
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Theme.green)
                    .font(.system(size: 16))
            }
            Text(weekSummaryText ?? fallback)
                .font(.system(size: 14))
                .foregroundColor(Theme.text)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                appState.needsNewWeekPlan = false
                appState.planMode = .input
            } label: {
                Text("Plan Week \(nextWeek) →")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.blue)
            }
        }
        .padding(16)
        .background(Theme.green.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.green.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: {
            #if os(iOS)
            ToolbarItemPlacement.topBarLeading
            #else
            ToolbarItemPlacement.navigation
            #endif
        }()) {
            Button { showSettings = true } label: {
                Image(systemName: "gearshape").foregroundColor(Theme.text)
            }
        }
        // Demo mood override — visible in all builds for prototype testing
        ToolbarItem(placement: {
            #if os(iOS)
            ToolbarItemPlacement.topBarTrailing
            #else
            ToolbarItemPlacement.primaryAction
            #endif
        }()) {
            Menu {
                Section(isLiveData ? "Demo · Override inactive (live data)" : "Demo · Override readiness") {
                    ForEach(ReadinessState.allCases) { state in
                        Button {
                            appState.readinessState = state
                        } label: {
                            if state == appState.readinessState && !isLiveData {
                                Label(state.label, systemImage: "checkmark")
                            } else {
                                Text(state.label)
                            }
                        }
                        .disabled(isLiveData)
                    }
                }
                if isLiveData {
                    Section {
                        Button("Refresh health data") {
                            Task { await readinessService.fetchReadiness() }
                        }
                    }
                }
            } label: {
                Image(systemName: "slider.horizontal.3").foregroundColor(Theme.text)
            }
        }
    }
}

// MARK: - Subviews

private struct VitalCell: View {
    let vital: Vital
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(vital.label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textMuted)
                .textCase(.uppercase)
                .tracking(0.6)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(vital.value)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Theme.text)
                if let unit = vital.unit {
                    Text(unit).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.textMuted)
                }
            }
            Text(vital.trend)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(trendColor(vital.trendDir))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func trendColor(_ d: TrendDir) -> Color {
        switch d {
        case .up:   return Theme.green
        case .down: return Theme.red
        case .flat: return Theme.textMuted
        }
    }
}

// MARK: - Flow layout for chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineH: CGFloat = 0
        for view in subviews {
            let s = view.sizeThatFits(.unspecified)
            if x + s.width > maxWidth { x = 0; y += lineH + spacing; lineH = 0 }
            x += s.width + spacing; lineH = max(lineH, s.height)
        }
        return CGSize(width: maxWidth, height: y + lineH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineH: CGFloat = 0
        for view in subviews {
            let s = view.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX { x = bounds.minX; y += lineH + spacing; lineH = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing; lineH = max(lineH, s.height)
        }
    }
}

// MARK: - WorkoutSessionView

// ─── Data models ──────────────────────────────────────────────────────────────

private struct WorkoutSet: Identifiable, Equatable {
    let id = UUID()
    let targetReps: String
    var weightLbs: Double = 0
    var completedReps: Int
    var rir: Int? = nil
    var isLogged: Bool = false
    var isWarmup: Bool = false   // warmup sets: lighter, no RIR required, shown as W1/W2
    var isSkipped: Bool = false  // set was skipped when user skipped the exercise

    var rirLabel: String? {
        guard let r = rir, !isWarmup else { return nil }
        switch r {
        case 0:     return "Max (0 RIR)"
        case 1:     return "Hard (1 RIR)"
        case 2, 3:  return "Good (2–3 RIR)"
        default:    return "Easy (4+ RIR)"
        }
    }
}

private struct WorkoutExercise: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let description: String
    var sets: [WorkoutSet]
    var isSkipped: Bool = false   // exercise was explicitly skipped

    // Warmup / working split
    var warmupSets: [WorkoutSet]  { sets.filter(\.isWarmup)  }
    var workingSets: [WorkoutSet] { sets.filter { !$0.isWarmup } }

    var completedWarmupCount: Int  { warmupSets.filter(\.isLogged).count }
    var completedWorkingCount: Int { workingSets.filter(\.isLogged).count }
    var totalWorkingCount: Int     { workingSets.count }

    var isFullyLogged: Bool {
        isSkipped || sets.allSatisfy { $0.isLogged || $0.isSkipped }
    }

    /// First logged working set awaiting a RIR rating (warmup sets skip RIR).
    var awaitingRIRIdx: Int? {
        sets.firstIndex { $0.isLogged && $0.rir == nil && !$0.isWarmup && !$0.isSkipped }
    }

    /// First set not yet logged and not skipped.
    var nextSetIdx: Int? { sets.firstIndex { !$0.isLogged && !$0.isSkipped } }

    /// Suggested weight for the next working set based on the last rated working set's RIR.
    var suggestedNextWeight: Double {
        guard let last = workingSets.filter(\.isLogged).last else { return 0 }
        let w = last.weightLbs
        switch last.rir {
        case .none:  return w
        case 0:      return max(0, (w * 0.9 / 2.5).rounded() * 2.5)
        case 1:      return w
        case 2, 3:   return w + 5
        default:     return w + 10
        }
    }

    /// Default warmup weight: 50 % of first working-set weight, rounded to nearest 5.
    var defaultWarmupWeight: Double {
        let w = workingSets.first?.weightLbs ?? 0
        return w > 0 ? max(0, (w * 0.5 / 5).rounded() * 5) : 0
    }

    /// Compact weight summary for collapsed display (working sets only).
    func weightSummary(useMetric: Bool) -> String {
        let ws = workingSets.filter(\.isLogged).map { s -> String in
            let v = useMetric ? s.weightLbs / 2.20462 : s.weightLbs
            return v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
        }
        guard !ws.isEmpty else { return "" }
        let unit = useMetric ? "kg" : "lbs"
        return Set(ws).count == 1 ? "\(ws[0]) \(unit)" : ws.joined(separator: "/") + " \(unit)"
    }

    var repsSummary: String {
        let rs = workingSets.filter(\.isLogged).map { $0.completedReps }
        guard !rs.isEmpty else { return "" }
        return Set(rs).count == 1 ? "\(rs[0]) reps" : rs.map { "\($0)" }.joined(separator: "/") + " reps"
    }

    /// Display number for a set at the given index (warmup → "W1"; working → 1-based count).
    func setDisplayNum(at index: Int) -> String {
        let set = sets[index]
        if set.isWarmup {
            let wNum = sets[..<index].filter(\.isWarmup).count + 1
            return "W\(wNum)"
        } else {
            let num = sets[..<index].filter { !$0.isWarmup }.count + 1
            return "\(num)"
        }
    }
}

// ─── Exercise description lookup ──────────────────────────────────────────────

private func exerciseCue(for name: String, reps: String = "8") -> String {
    let key = name.lowercased()
    let cues: [(String, String)] = [
        ("back squat",    "Bar on upper traps, feet shoulder-width. Brace core, sit back and down, drive knees over toes. Stand through heels."),
        ("goblet squat",  "Hold weight at chest, elbows inside knees. Squat deep keeping chest tall and heels flat."),
        ("walking lunge", "Step forward, lower back knee toward floor. Keep front shin vertical. Push off front foot to step through."),
        ("rdl",           "Hinge at hips with soft knees — bar stays close to legs. Feel hamstring stretch, then drive hips forward."),
        ("bench press",   "Natural arch, feet flat. Lower to lower chest with elbows ~45°. Press in a slight arc to lockout."),
        ("bent row",      "Hip-hinged, back flat. Pull to lower ribcage leading with elbows. Squeeze shoulder blades at top."),
        ("ohp",           "Bar at collar bone, elbows just forward. Press straight up and lock out overhead. Brace abs throughout."),
        ("pull-up",       "Dead hang start. Retract shoulder blades, pull chin over bar, control the descent fully."),
        ("calf raise",    "Full ROM: deep stretch at bottom, peak contraction at top. Control beats load."),
        ("leg press",     "Feet hip-width, lower to ~90°. Press through whole foot, avoid locking out the knees."),
        ("hip thrust",    "Shoulders on bench. Drive hips to full extension, squeeze glutes hard at the top."),
        ("tempo",         "Build to 85–90% effort. Breathing labored but rhythmic. Maintain form throughout."),
        ("easy z2",       "Conversational pace — full sentences comfortable. Heart rate below 140 bpm."),
        ("easy walk",     "Relaxed stroll. Heart rate well below 120 bpm. This is active recovery."),
        ("mobility",      "Move through gentle ranges. Hold each stretch 20–30 s. Never bounce or force."),
        ("yoga",          "Synchronize breath with movement. Relax into each pose; don't force range of motion."),
    ]
    let formCue = cues.first(where: { key.contains($0.0) })?.1
        ?? "Focus on controlled movement. Maintain form over load — quality reps drive results."
    return formCue + "\n\n" + rirTargetCue(for: reps)
}

/// Returns a concise RIR effort target based on the planned rep count.
private func rirTargetCue(for reps: String) -> String {
    if reps.lowercased() == "amrap" {
        return "Effort target: go to technical failure — stop at the last rep where your form is solid, not one rep further."
    }
    let n = Int(reps) ?? 8
    switch n {
    case ...3:
        return "Effort target: 1 RIR (Reps In Reserve). It should feel like a hard grind; if you genuinely cannot do one more rep with good form, you're right at the limit. Reduce weight if you reach 0 RIR on set 1."
    case 4...6:
        return "Effort target: 1–2 RIR. Stop when you have 1–2 strong reps left. The last rep should feel tough but controlled — never a grind that breaks your form."
    case 7...10:
        return "Effort target: 2–3 RIR. Stop before form starts to crack. Some muscular burn is expected; if your tempo slows significantly or your chest drops, that's your stop point."
    default:
        return "Effort target: 3–4 RIR. Higher rep sets build capacity — the burn will come early. Keep a steady tempo and stop 3–4 reps before full failure."
    }
}

// ─── RIR option definition ────────────────────────────────────────────────────

private let rirOptions: [(label: String, subtitle: String, value: Int, color: Color)] = [
    ("Easy",  "4+ RIR",  4, Theme.blue),
    ("Good",  "2–3 RIR", 2, Theme.green),
    ("Hard",  "1 RIR",   1, Theme.yellow),
    ("Max",   "Failure", 0, Theme.red),
]

// ─── WorkoutSessionView ───────────────────────────────────────────────────────

struct WorkoutSessionView: View {
    let session: PlanSession
    let readiness: ReadinessState
    let chips: [String]

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var readinessService: ReadinessService
    @Environment(\.dismiss) private var dismiss

    @State private var elapsed: Int = 0
    @State private var currentHR: Int? = nil
    @State private var hrSamples: [Int] = []
    @State private var exercises: [WorkoutExercise] = []
    @State private var isSaving = false
    @State private var showSummary = false
    @State private var editingSetID: UUID? = nil
    @FocusState private var weightFieldFocused: Bool

    private let startDate = Date()
    private let timerPublisher = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isLift: Bool { session.kind == .lift }
    private var effectiveName: String { readiness == .red ? "Easy Z2 walk + mobility" : session.name }
    private var targetMinutes: Int {
        readiness == .red ? 30 : (readiness == .yellow ? session.durationMin * 4 / 5 : session.durationMin)
    }
    private var kcalBurned: Int {
        let met: Double
        switch session.kind { case .lift: met = 5; case .run: met = 9; case .yoga: met = 2.5; case .rest: met = 3 }
        return Int(met * max(appState.user.weightLb, 100) * 0.453592 * Double(elapsed) / 3600)
    }
    private var accentColor: Color {
        switch session.kind { case .lift: Theme.orange; case .run: Theme.green; case .yoga: Theme.purple; case .rest: Theme.textMuted }
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            if showSummary {
                WorkoutSummaryView(exercises: exercises, sessionName: effectiveName,
                                   elapsed: elapsed, kcalBurned: kcalBurned, onFinish: finishWorkout)
            } else {
                VStack(spacing: 0) {
                    header
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            statsBar
                            if isLift { liftContent } else { cardioContent }
                            completionFooter
                        }
                        .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 28)
                    }
                }
            }
        }
        .onReceive(timerPublisher) { _ in elapsed += 1 }
        .onAppear {
            if isLift { exercises = buildExercises(from: chips) }
            Analytics.workoutStarted(kind: session.kind.rawValue,
                                     readinessState: readiness.rawValue)
            if isLift {
                appState.watchService.sendWorkoutSync(toSyncPayload(isActive: true))
            }
        }
        .onChange(of: exercises) { _, _ in
            guard isLift else { return }
            appState.watchService.sendWorkoutSync(toSyncPayload(isActive: true))
        }
        .onChange(of: appState.pendingWatchWorkoutUpdate) { _, update in
            guard let update, update.source == "watch", isLift else { return }
            applyWatchUpdate(update)
            appState.pendingWatchWorkoutUpdate = nil
        }
        .task {
            while !Task.isCancelled {
                if let hr = await readinessService.fetchCurrentHeartRate() {
                    currentHR = hr
                    hrSamples.append(hr)
                }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { weightFieldFocused = false; editingSetID = nil }
                    .fontWeight(.semibold)
            }
        }
    }

    // MARK: - Watch sync helpers

    private func toSyncPayload(isActive: Bool) -> WorkoutSyncPayload {
        let activeIdx = exercises.firstIndex(where: { !$0.isFullyLogged }) ?? exercises.count
        return WorkoutSyncPayload(
            workoutName: effectiveName,
            exercises: exercises.map { ex in
                SyncExercise(
                    name: ex.name,
                    sets: ex.workingSets.map { s in
                        SyncSet(targetReps: Int(s.targetReps) ?? 8,
                                completedReps: s.completedReps,
                                weightLbs: s.weightLbs,
                                isLogged: s.isLogged)
                    }
                )
            },
            exerciseIndex: activeIdx,
            elapsed: elapsed,
            isActive: isActive,
            source: "phone"
        )
    }

    private func applyWatchUpdate(_ payload: WorkoutSyncPayload) {
        for (ei, syncEx) in payload.exercises.enumerated() {
            guard ei < exercises.count else { break }
            let workingIdxs = exercises[ei].sets.indices.filter {
                !exercises[ei].sets[$0].isWarmup && !exercises[ei].sets[$0].isSkipped
            }
            for (si, syncSet) in syncEx.sets.enumerated() {
                guard si < workingIdxs.count else { break }
                let idx = workingIdxs[si]
                exercises[ei].sets[idx].weightLbs    = syncSet.weightLbs
                exercises[ei].sets[idx].completedReps = syncSet.completedReps
                if syncSet.isLogged && !exercises[ei].sets[idx].isLogged {
                    exercises[ei].sets[idx].isLogged = true
                    exercises[ei].sets[idx].rir = 2  // auto-rate so RIR picker doesn't block
                }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        ZStack {
            VStack(spacing: 6) {
                Text(effectiveName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textBody)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .lineLimit(1)
                if readiness != .green {
                    Text("ADJUSTED")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(Theme.gold)
                        .tracking(1.2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Theme.gold.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(Theme.gold, lineWidth: 1.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
            }

            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(Theme.text)
                        .frame(width: 38, height: 38)
                        .background(Theme.card2)
                        .clipShape(Circle())
                }
                Spacer()
            }
        }
        .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 10)
    }

    // MARK: Stats bar

    private var statsBar: some View {
        HStack(spacing: 0) {
            statCell(icon: "heart.fill",  color: Theme.red,    value: currentHR.map { "\($0)" } ?? "—", unit: "BPM")
            Rectangle().fill(Theme.separator).frame(width: 1, height: 46)
            statCell(icon: "flame.fill",  color: Theme.orange, value: "\(kcalBurned)",                  unit: "KCAL")
            Rectangle().fill(Theme.separator).frame(width: 1, height: 46)
            statCell(icon: isLift ? "clock" : "timer", color: Theme.orange, value: fmt(elapsed),         unit: "ELAPSED")
        }
        .padding(.vertical, 16)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func statCell(icon: String, color: Color, value: String, unit: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(color)
                .frame(height: 20)
            Text(value)
                .font(.system(size: 25, weight: .bold))
                .foregroundColor(Theme.text)
                .kerning(0.3)
            Text(unit)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textBody)
                .tracking(1.0)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Lift — exercise accordion

    private var liftContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if exercises.isEmpty {
                Text("See your plan for exercise details.")
                    .font(.system(size: 14)).foregroundColor(Theme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 24)
            } else {
                let activeIdx = exercises.firstIndex(where: { !$0.isFullyLogged })
                ForEach(Array(exercises.indices), id: \.self) { idx in
                    if idx == activeIdx        { activeCard(idx: idx) }
                    else if exercises[idx].isFullyLogged { doneRow(idx: idx) }
                    else                       { upcomingRow(idx: idx) }
                }
            }
        }
    }

    // MARK: Active card (v2 set-table layout)

    private func activeCard(idx: Int) -> some View {
        let ex = exercises[idx]
        let nextIdx = ex.nextSetIdx
        let activeSet = nextIdx.map { ex.sets[$0] }
        let allDone = ex.isFullyLogged
        let workingDone = ex.completedWorkingCount
        let workingTotal = ex.totalWorkingCount

        return VStack(alignment: .leading, spacing: 16) {

            // Title + "Add to" menu
            HStack(alignment: .center, spacing: 12) {
                Text(ex.name)
                    .font(.system(size: 26, weight: .heavy))
                    .italic()
                    .foregroundColor(Theme.text)
                    .kerning(-0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Menu {
                    Button { addSet(to: idx) } label: {
                        Label("Add set", systemImage: "plus.square")
                    }
                    Button { addWarmupSet(to: idx) } label: {
                        Label("Add warmup", systemImage: "figure.strengthtraining.traditional")
                    }
                    Button(role: .destructive) { removeLastSet(from: idx) } label: {
                        Label("Remove last set", systemImage: "minus.square")
                    }
                    .disabled(exercises[idx].workingSets.filter { !$0.isLogged }.count <= 1)
                    Divider()
                    Button(role: .destructive) { skipExercise(idx: idx) } label: {
                        Label("Skip exercise", systemImage: "forward.end.fill")
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Add to")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(Theme.textBody)
                    .padding(.horizontal, 13)
                    .frame(height: 36)
                    .background(Theme.card2)
                    .overlay(Capsule().stroke(Color.white.opacity(0.07), lineWidth: 1))
                    .clipShape(Capsule())
                }
            }

            // Toolbar pills (Rest / History / Replace / More)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    toolbarPill(icon: "timer", iconColor: Theme.mint, label: "1:30 Rest")
                    toolbarPill(icon: "clock.arrow.circlepath", iconColor: Theme.textBody, label: "History")
                    toolbarPill(icon: "arrow.left.arrow.right", iconColor: Theme.textBody, label: "Replace")
                    toolbarPill(icon: "ellipsis", iconColor: Theme.textBody, label: nil)
                }
            }

            // Coaching cue
            VStack(alignment: .leading, spacing: 5) {
                Text(allDone
                     ? "All working sets logged. Nice work."
                     : (activeSet?.isWarmup == true
                        ? "Warmup \(ex.completedWarmupCount + 1) of \(ex.warmupSets.count) · lighter, no RIR"
                        : "Working set \(workingDone + 1) of \(workingTotal) · target 2–3 RIR"))
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textBody)
                Text(adjustedCueText)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textGhost)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Column headers
            HStack(spacing: 14) {
                Text("SET")
                    .frame(width: 32)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(Theme.textGhost)
                    .tracking(1)
                Text("REPS")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(Theme.textGhost)
                    .tracking(1)
                Text("WEIGHT")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(Theme.textGhost)
                    .tracking(1)
            }
            .padding(.horizontal, 4)

            // Set rows
            VStack(spacing: 0) {
                ForEach(Array(ex.sets.enumerated()), id: \.element.id) { i, _ in
                    setTableRow(exIdx: idx, setIdx: i, isActive: i == nextIdx)
                    if i < ex.sets.count - 1 {
                        Rectangle()
                            .fill(Theme.separator)
                            .frame(height: 1)
                            .padding(.horizontal, 4)
                    }
                }
            }

            // RIR rating (appears inline when a working set is awaiting rating)
            if let rirIdx = ex.awaitingRIRIdx {
                rirSection(exIdx: idx, setIdx: rirIdx)
            }

            // Action buttons (Log all sets | Log set N) — proportional widths
            GeometryReader { geo in
                let spacing: CGFloat = 10
                let totalFlex: CGFloat = 1.0 + 1.7
                let avail = geo.size.width - spacing
                HStack(spacing: spacing) {
                    Button {
                        logAllRemainingSets(in: idx)
                    } label: {
                        Text("Log all sets")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(allDone ? Theme.textGhost : Theme.text)
                            .frame(width: avail * (1.0 / totalFlex), height: 54)
                            .background(Theme.card2)
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(allDone)

                    Button {
                        logCurrentSet(in: idx)
                    } label: {
                        Text(allDone ? "All sets logged"
                             : (activeSet?.isWarmup == true
                                ? "Log warmup \(ex.completedWarmupCount + 1)"
                                : "Log set \(workingDone + 1)"))
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundColor(allDone ? Theme.textGhost : .white)
                            .frame(width: avail * (1.7 / totalFlex), height: 54)
                            .background(allDone ? Theme.card2 : Theme.pink)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: allDone ? .clear : Theme.pink.opacity(0.35), radius: 12, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)
                    .disabled(allDone)
                }
            }
            .frame(height: 54)
        }
        .padding(EdgeInsets(top: 20, leading: 16, bottom: 16, trailing: 16))
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .animation(.spring(response: 0.35), value: ex.awaitingRIRIdx)
        .animation(.spring(response: 0.35), value: ex.nextSetIdx)
    }

    /// Concise secondary line under the cue, mentioning load adjustment when relevant.
    private var adjustedCueText: String {
        switch readiness {
        case .yellow: return "−20% load adjustment. Stop before form breaks down."
        case .red:    return "Easy day — keep load very light. Form first, always."
        case .green:  return "Stop before form breaks down. Quality beats load."
        }
    }

    // MARK: Toolbar pill

    private func toolbarPill(icon: String, iconColor: Color, label: String?) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(iconColor)
            if let label = label {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textBody)
            }
        }
        .padding(.horizontal, label == nil ? 0 : 14)
        .frame(width: label == nil ? 38 : nil, height: 38)
        .background(Theme.card2)
        .overlay(Capsule().stroke(Color.white.opacity(0.07), lineWidth: 1))
        .clipShape(Capsule())
    }

    // MARK: Set-table row (active / done / upcoming)

    private func setTableRow(exIdx: Int, setIdx: Int, isActive: Bool) -> some View {
        let set = exercises[exIdx].sets[setIdx]
        let isDone = set.isLogged
        let isSkipped = set.isSkipped
        let isEditing = isDone && editingSetID == set.id
        let displayNum = exercises[exIdx].setDisplayNum(at: setIdx)
        let valueColor: Color = isDone ? Theme.mint : (isActive ? Theme.text : Theme.textGhost)

        return HStack(spacing: 14) {
            // Status indicator
            Group {
                if isDone && isEditing {
                    ZStack {
                        Circle().fill(Theme.card2)
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(Theme.textMuted)
                    }
                    .frame(width: 26, height: 26)
                    .onTapGesture { weightFieldFocused = false; editingSetID = nil }
                } else if isDone {
                    ZStack {
                        Circle().fill(Theme.mint)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(Theme.mintInk)
                    }
                    .frame(width: 26, height: 26)
                } else if isActive {
                    ZStack {
                        Circle().fill(Theme.pinkDim)
                        Circle().stroke(Theme.pink, lineWidth: 2)
                        Text(displayNum)
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundColor(Theme.pink)
                    }
                    .frame(width: 26, height: 26)
                } else {
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.18), lineWidth: 2)
                        Text(displayNum)
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundColor(isSkipped ? Theme.textGhost.opacity(0.6) : Theme.textGhost)
                    }
                    .frame(width: 26, height: 26)
                }
            }
            .frame(width: 32, alignment: .center)

            // Reps column
            if isActive || isEditing {
                inlineField(
                    binding: Binding<String>(
                        get: { String(exercises[exIdx].sets[setIdx].completedReps) },
                        set: { str in
                            let digits = str.filter(\.isNumber)
                            exercises[exIdx].sets[setIdx].completedReps = Int(digits) ?? 0
                        }
                    ),
                    subLabel: "reps",
                    keyboardDecimal: false
                )
            } else {
                Text("\(set.completedReps)")
                    .font(.system(size: 22, weight: .heavy))
                    .italic()
                    .foregroundColor(valueColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(isSkipped ? 0.5 : 1)
            }

            // Weight column
            if isActive || isEditing {
                inlineField(
                    binding: Binding<String>(
                        get: {
                            let w = exercises[exIdx].sets[setIdx].weightLbs
                            return w > 0 ? wStr(w) : ""
                        },
                        set: { str in
                            let cleaned = str.replacingOccurrences(of: ",", with: ".")
                            if let val = Double(cleaned), val >= 0 {
                                exercises[exIdx].sets[setIdx].weightLbs = appState.storedWeightLbs(val)
                            } else if str.isEmpty {
                                exercises[exIdx].sets[setIdx].weightLbs = 0
                            }
                        }
                    ),
                    subLabel: appState.useMetric ? "kg" : "lbs",
                    keyboardDecimal: true
                )
            } else {
                HStack(spacing: 3) {
                    if set.weightLbs > 0 {
                        Text(wStr(set.weightLbs))
                            .font(.system(size: 22, weight: .heavy))
                            .italic()
                            .foregroundColor(valueColor)
                        if !isDone {
                            Text(appState.useMetric ? "kg" : "lb")
                                .font(.system(size: 13, weight: .semibold))
                                .italic()
                                .foregroundColor(Theme.textGhost)
                        }
                    } else {
                        Text("—")
                            .font(.system(size: 22, weight: .heavy))
                            .italic()
                            .foregroundColor(valueColor)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(isSkipped ? 0.5 : 1)
            }
        }
        .padding(.vertical, isActive || isEditing ? 12 : 13)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill((isActive || isEditing) ? Color.white.opacity(0.035) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isDone && !isEditing { editingSetID = set.id }
        }
    }

    /// Editable inline field used by the active set row (large bold numeric input + sub-label).
    private func inlineField(binding: Binding<String>, subLabel: String, keyboardDecimal: Bool) -> some View {
        VStack(spacing: 5) {
            TextField("", text: binding)
                .font(.system(size: 24, weight: .heavy))
                .foregroundColor(Theme.text)
                .multilineTextAlignment(.center)
                .focused($weightFieldFocused)
                #if canImport(UIKit)
                .keyboardType(keyboardDecimal ? .decimalPad : .numberPad)
                #endif
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(0.25))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.inputBorder, lineWidth: 1.5)
                )
            Text(subLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.textGhost)
                .tracking(0.2)
        }
    }

    // MARK: Log helpers

    /// Logs the currently active set. Working sets fall into RIR rating afterwards.
    private func logCurrentSet(in exIdx: Int) {
        guard let nextIdx = exercises[exIdx].nextSetIdx else { return }
        weightFieldFocused = false
        withAnimation(.spring(response: 0.3)) {
            exercises[exIdx].sets[nextIdx].isLogged = true
            if exercises[exIdx].sets[nextIdx].isWarmup {
                exercises[exIdx].sets[nextIdx].rir = 2  // warmup: skip RIR
            }
        }
    }

    /// Logs every remaining set with the current target/inputs — skips RIR (auto-rates Good).
    private func logAllRemainingSets(in exIdx: Int) {
        weightFieldFocused = false
        withAnimation(.spring(response: 0.3)) {
            for i in exercises[exIdx].sets.indices where !exercises[exIdx].sets[i].isLogged
                && !exercises[exIdx].sets[i].isSkipped {
                exercises[exIdx].sets[i].isLogged = true
                exercises[exIdx].sets[i].rir = 2
            }
        }
    }

    // MARK: RIR rating section

    private func rirSection(exIdx: Int, setIdx: Int) -> some View {
        let setNum = exercises[exIdx].sets[..<setIdx].filter { !$0.isWarmup }.count + 1
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Rate effort · set \(setNum)")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(Theme.textGhost)
                    .tracking(1)
                Text("How many more reps could you have done?")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textBody)
            }

            HStack(spacing: 8) {
                ForEach(rirOptions, id: \.value) { opt in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            exercises[exIdx].sets[setIdx].rir = opt.value
                            let next = setIdx + 1
                            if next < exercises[exIdx].sets.count {
                                exercises[exIdx].sets[next].weightLbs = exercises[exIdx].suggestedNextWeight
                            }
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Text(opt.label).font(.system(size: 14, weight: .heavy))
                            Text(opt.subtitle).font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(opt.color)
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .background(opt.color.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(opt.color.opacity(0.35), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button("Skip rating") {
                withAnimation { exercises[exIdx].sets[setIdx].rir = 2 }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(Theme.textGhost)
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .background(Color.white.opacity(0.03))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: Collapsed rows

    private func doneRow(idx: Int) -> some View {
        let ex = exercises[idx]
        let skipped = ex.isSkipped
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(skipped ? Theme.card2 : Theme.mint)
                Image(systemName: skipped ? "forward.end.fill" : "checkmark")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(skipped ? Theme.textMuted : Theme.mintInk)
            }
            .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(ex.name)
                    .font(.system(size: 15, weight: .heavy))
                    .italic()
                    .foregroundColor(skipped ? Theme.textMuted : Theme.text)
                if skipped {
                    Text("Skipped").font(.system(size: 12)).foregroundColor(Theme.textMuted)
                } else {
                    let warmupDone = ex.completedWarmupCount
                    let parts = [
                        warmupDone > 0 ? "\(warmupDone)W warmup" : nil,
                        !ex.weightSummary(useMetric: appState.useMetric).isEmpty ? "\(ex.weightSummary(useMetric: appState.useMetric)) · \(ex.repsSummary)" : nil
                    ].compactMap { $0 }
                    if !parts.isEmpty {
                        Text(parts.joined(separator: " · "))
                            .font(.system(size: 12)).foregroundColor(Theme.textBody)
                    }
                }
            }
            Spacer()
            if !skipped {
                Text("\(ex.completedWorkingCount) sets").font(.system(size: 12)).foregroundColor(Theme.textBody)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(skipped ? Theme.card : Theme.mint.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func upcomingRow(idx: Int) -> some View {
        let ex = exercises[idx]
        return HStack(spacing: 12) {
            Circle().stroke(Color.white.opacity(0.18), lineWidth: 2).frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(ex.name)
                    .font(.system(size: 15, weight: .heavy))
                    .italic()
                    .foregroundColor(Theme.textBody)
                Text("\(ex.sets.count) sets · \(ex.sets.first?.targetReps ?? "?") reps")
                    .font(.system(size: 12)).foregroundColor(Theme.textGhost)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Cardio content

    private var cardioContent: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().stroke(Theme.card2, lineWidth: 14).frame(width: 210, height: 210)
                Circle()
                    .trim(from: 0, to: min(1, Double(elapsed) / Double(max(targetMinutes * 60, 1))))
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .frame(width: 210, height: 210).rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: elapsed)
                VStack(spacing: 4) {
                    Text(fmt(elapsed)).font(.system(size: 42, weight: .bold, design: .monospaced)).foregroundColor(Theme.text)
                    Text("of \(targetMinutes) min").font(.system(size: 13)).foregroundColor(Theme.textMuted)
                }
            }.padding(.top, 8)

            if !chips.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Notes").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.textMuted)
                        .textCase(.uppercase).tracking(0.6)
                    ForEach(chips, id: \.self) { chip in
                        HStack(spacing: 10) {
                            Circle().fill(accentColor).frame(width: 6, height: 6)
                            Text(chip).font(.system(size: 14)).foregroundColor(Theme.text)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(16).background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    // MARK: Footer

    /// Inline footer rendered at the end of the scrollable workout list —
    /// "Mark complete" appears after the last exercise/cardio segment instead
    /// of competing with active sets in a sticky bar.
    private var completionFooter: some View {
        VStack(spacing: 14) {
            Button {
                withAnimation { showSummary = true }
            } label: {
                Text("Mark complete")
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundColor(isLift ? Theme.mintInk : .black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(isLift ? Theme.mint : Theme.green)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            Button("End early — don't log") { dismiss() }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.textBody)
        }
        .padding(.top, 4)
    }

    // MARK: Helpers

    private func fmt(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }
    /// Returns the weight as a plain number string in the user's chosen unit (no suffix).
    private func wStr(_ w: Double) -> String {
        let v = appState.displayWeight(w)
        return v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
    }

    private func buildExercises(from chips: [String]) -> [WorkoutExercise] {
        chips.compactMap { chip in
            guard let xr = chip.range(of: "×") else { return nil }
            let before = String(chip[..<xr.lowerBound]).components(separatedBy: " ")
            guard let setCount = Int(before.last ?? ""), setCount > 0 else { return nil }
            let name = before.dropLast().joined(separator: " ")
            guard !name.isEmpty else { return nil }
            let repsStr = String(chip[xr.upperBound...]).trimmingCharacters(in: .whitespaces)
            let defaultReps = Int(repsStr) ?? 8
            // Pre-populate weight from the last session's history-derived suggestion.
            let suggested = appState.suggestedWeight(for: name, targetRepsStr: repsStr) ?? 0
            let sets = (0..<setCount).map { _ in
                WorkoutSet(targetReps: repsStr, weightLbs: suggested, completedReps: defaultReps)
            }
            return WorkoutExercise(name: name, description: exerciseCue(for: name, reps: repsStr), sets: sets)
        }
    }

    // MARK: Set modification actions

    /// Appends one more working set (same target reps as the last working set).
    private func addSet(to exIdx: Int) {
        let ex = exercises[exIdx]
        let template = ex.workingSets.last
        let newSet = WorkoutSet(
            targetReps: template?.targetReps ?? "8",
            completedReps: Int(template?.targetReps ?? "8") ?? 8
        )
        withAnimation(.spring(response: 0.3)) {
            exercises[exIdx].sets.append(newSet)
        }
    }

    /// Removes the last unlogged working set (minimum 1 working set remains).
    private func removeLastSet(from exIdx: Int) {
        let indices = exercises[exIdx].sets.indices.filter {
            !exercises[exIdx].sets[$0].isWarmup && !exercises[exIdx].sets[$0].isLogged
        }
        guard indices.count > 1, let last = indices.last else { return }
        _ = withAnimation(.spring(response: 0.3)) {
            exercises[exIdx].sets.remove(at: last)
        }
    }

    /// Inserts a warmup set before the working sets (suggested at 50 % of working weight).
    private func addWarmupSet(to exIdx: Int) {
        let ex = exercises[exIdx]
        let suggested = ex.defaultWarmupWeight
        let reps = ex.workingSets.first?.targetReps ?? "8"
        let warmup = WorkoutSet(
            targetReps: reps,
            weightLbs: suggested,
            completedReps: Int(reps) ?? 8,
            isWarmup: true
        )
        // Insert before first working set
        let insertAt = ex.sets.firstIndex(where: { !$0.isWarmup }) ?? ex.sets.count
        withAnimation(.spring(response: 0.3)) {
            exercises[exIdx].sets.insert(warmup, at: insertAt)
        }
    }

    /// Marks all remaining unlogged sets as skipped and flags the exercise as skipped.
    private func skipExercise(idx: Int) {
        withAnimation(.spring(response: 0.3)) {
            for i in exercises[idx].sets.indices where !exercises[idx].sets[i].isLogged {
                exercises[idx].sets[i].isSkipped = true
            }
            exercises[idx].isSkipped = true
        }
    }

    private func finishWorkout() {
        isSaving = true
        if isLift { appState.watchService.sendWorkoutSync(toSyncPayload(isActive: false)) }

        // Persist working-set weights so future sessions get suggested starting weights.
        if isLift {
            for ex in exercises where !ex.isSkipped {
                let logged = ex.workingSets.filter { $0.isLogged && !$0.isSkipped && $0.weightLbs > 0 }
                guard !logged.isEmpty else { continue }
                appState.logExercise(ex.name, sets: logged.map { (weight: $0.weightLbs, reps: $0.completedReps) })
            }
        }

        let end = Date()
        let activityType: HKWorkoutActivityType
        switch session.kind {
        case .lift: activityType = .traditionalStrengthTraining
        case .run:  activityType = .running
        case .yoga: activityType = .yoga
        case .rest: activityType = .walking
        }
        let met: Double
        switch session.kind { case .lift: met = 5; case .run: met = 9; case .yoga: met = 2.5; case .rest: met = 3 }
        let bodyKg = max(appState.user.weightLb, 100) * 0.453592
        let hours   = Double(elapsed) / 3600
        let kcal    = met * bodyKg * hours

        // Estimated distance for runs/walks: use a pace appropriate to the readiness state.
        // No GPS is available, so this is MET-derived rather than tracked.
        let distanceMeters: Double? = {
            guard session.kind == .run || session.kind == .rest else { return nil }
            let speedMs: Double = session.kind == .run ? 2.7 : 1.3  // ~9.7 km/h run, ~4.7 km/h walk
            return speedMs * Double(elapsed)
        }()

        let avgHR: Int? = hrSamples.isEmpty ? nil : hrSamples.reduce(0, +) / hrSamples.count
        let summary = CompletedWorkoutSummary(
            sessionName: effectiveName,
            kind: session.kind,
            elapsedSeconds: elapsed,
            kcalBurned: kcalBurned,
            avgHR: avgHR,
            exercises: isLift ? exercises.map { ex in
                let best = ex.workingSets
                    .filter { $0.isLogged && !$0.isSkipped && $0.weightLbs > 0 && $0.completedReps > 0 }
                    .map { $0.weightLbs * (1 + Double($0.completedReps) / 30) }
                    .max()
                return CompletedExerciseSummary(
                    name: ex.name,
                    wasSkipped: ex.isSkipped,
                    loggedSets: ex.sets.filter(\.isLogged).map { (reps: $0.completedReps, weightLbs: $0.weightLbs, isWarmup: $0.isWarmup) },
                    bestOneRM: (best ?? 0) > 0 ? best : nil
                )
            } : []
        )

        Task {
            Analytics.workoutCompleted(
                kind: session.kind.rawValue,
                elapsedSeconds: elapsed,
                setsLogged: exercises.flatMap(\.sets).filter(\.isLogged).count
            )
            try? await readinessService.saveWorkout(
                activityType: activityType,
                start: startDate, end: end,
                energyKcal: kcal > 1 ? kcal : nil,
                distanceMeters: distanceMeters
            )
            appState.completedWorkoutSummary = summary
            appState.acceptTodaySession()
            dismiss()
        }
    }
}

// MARK: - WorkoutSummaryView

private struct WorkoutSummaryView: View {
    @EnvironmentObject var appState: AppState
    let exercises: [WorkoutExercise]
    let sessionName: String
    let elapsed: Int
    let kcalBurned: Int
    let onFinish: () -> Void

    private var totalSets: Int { exercises.flatMap(\.sets).filter(\.isLogged).count }
    private var totalVolumeLbs: Int {
        exercises.flatMap(\.sets).filter(\.isLogged)
            .reduce(0) { $0 + Int($1.weightLbs) * $1.completedReps }
    }
    private var displayVolume: Int { Int(appState.displayWeight(Double(totalVolumeLbs)).rounded()) }
    private var volumeLabel: String { totalVolumeLbs > 0 ? "\(appState.weightUnit) total vol." : "Volume" }
    private func fmt(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // Celebration header
                    VStack(spacing: 10) {
                        Text("💪").font(.system(size: 72))
                        Text("Great work!").font(.system(size: 32, weight: .bold)).foregroundColor(Theme.text)
                        Text(sessionName).font(.system(size: 15)).foregroundColor(Theme.textMuted)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 44)

                    // Stats grid
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            summaryTile(value: fmt(elapsed),     label: "Duration",    icon: "timer",                color: Theme.blue)
                            summaryTile(value: "\(kcalBurned)",  label: "Calories",    icon: "flame.fill",           color: Theme.orange)
                        }
                        HStack(spacing: 8) {
                            summaryTile(value: "\(totalSets)",   label: "Sets logged", icon: "checkmark.circle.fill", color: Theme.green)
                            summaryTile(
                                value: totalVolumeLbs > 0 ? "\(displayVolume)" : "—",
                                label: volumeLabel,
                                icon: "scalemass.fill", color: Theme.purple)
                        }
                    }

                    // Per-exercise breakdown
                    if !exercises.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Session breakdown")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.textMuted).textCase(.uppercase).tracking(0.6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            ForEach(exercises) { ex in
                                exerciseBreakdown(ex: ex)
                            }
                        }
                    }

                    PrimaryButton(title: "Finish", tint: Theme.green, action: onFinish)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 22).padding(.bottom, 48)
            }
        }
    }

    private func summaryTile(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 22)).foregroundColor(color)
            Text(value).font(.system(size: 26, weight: .bold, design: .rounded)).foregroundColor(Theme.text)
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.textMuted)
                .textCase(.uppercase).tracking(0.5).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 20)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func exerciseBreakdown(ex: WorkoutExercise) -> some View {
        let loggedSets = ex.sets.filter(\.isLogged)
        // Epley 1RM from the best working set in this session
        let oneRM: Double? = {
            let best = ex.workingSets
                .filter { $0.isLogged && !$0.isSkipped && $0.weightLbs > 0 && $0.completedReps > 0 }
                .map { $0.weightLbs * (1 + Double($0.completedReps) / 30) }
                .max()
            return (best ?? 0) > 0 ? best : nil
        }()
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ex.name).font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ex.isSkipped ? Theme.textMuted : Theme.text)
                    if let rm = oneRM, !ex.isSkipped {
                        Text("Est. 1RM: \(Int(rm.rounded())) lbs")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.blue)
                    }
                }
                Spacer()
                if ex.isSkipped {
                    Text("Skipped").font(.system(size: 12)).foregroundColor(Theme.textMuted)
                } else {
                    Image(systemName: ex.isFullyLogged ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(ex.isFullyLogged ? Theme.green : Theme.textMuted)
                        .font(.system(size: 16))
                }
            }
            if loggedSets.isEmpty && !ex.isSkipped {
                Text("Not started").font(.system(size: 13)).foregroundColor(Theme.textMuted)
            } else if !loggedSets.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(loggedSets.enumerated()), id: \.offset) { i, s in
                        let globalIdx = ex.sets.firstIndex(where: { $0.id == s.id }) ?? i
                        let dispNum = ex.setDisplayNum(at: globalIdx)
                        HStack(spacing: 0) {
                            Text(dispNum).font(.system(size: 12, weight: .semibold))
                                .foregroundColor(s.isWarmup ? Theme.orange : Theme.textMuted)
                                .frame(width: 36, alignment: .leading)
                            if s.isWarmup {
                                Text("W ").font(.system(size: 10, weight: .bold)).foregroundColor(Theme.orange)
                            }
                            Text(s.weightLbs > 0 ? appState.formatWeight(s.weightLbs) : "BW")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(s.isWarmup ? Theme.textMuted : Theme.text)
                            Text(" × ").font(.system(size: 13)).foregroundColor(Theme.textMuted)
                            Text("\(s.completedReps) reps")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(s.isWarmup ? Theme.textMuted : Theme.text)
                            if !s.isWarmup {
                                Text("  (tgt \(s.targetReps))").font(.system(size: 11)).foregroundColor(Theme.textMuted)
                            }
                            Spacer()
                            if let label = s.rirLabel {
                                Text(label).font(.system(size: 11)).foregroundColor(Theme.textMuted)
                            }
                        }
                    }
                }
            }
        }
        .padding(14).background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    NavigationStack { TodayView() }
        .environmentObject(AppState())
        .environmentObject(AuthService())
        .environmentObject(ReadinessService())
        .environmentObject(FoundationModelService())
        .preferredColorScheme(.dark)
}

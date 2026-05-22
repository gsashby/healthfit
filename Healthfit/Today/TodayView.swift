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
    @State private var showSettings = false

    @State private var showWorkoutSession = false

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
                    readinessCard
                    vitalsRow
                    workoutCard
                    reasoningCard
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
        }
        .sheet(isPresented: $showWorkoutSession) {
            if let todayDay = appState.currentPlan.days.first(where: { $0.isToday }),
               let session = todayDay.sessions.first(where: { $0.kind != .rest }) ?? todayDay.sessions.first {
                WorkoutSessionView(session: session, readiness: activeReadiness)
                    .environmentObject(appState)
                    .environmentObject(readinessService)
            }
        }
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
            }
            .padding(22)
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: Vitals

    private var vitalsRow: some View {
        HStack(spacing: 8) {
            ForEach(snapshot.vitals) { vital in VitalCell(vital: vital) }
        }
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
            message: snapshot.reasoning,
            tint: accent
        )
    }

    // MARK: Actions

    private var actionsRow: some View {
        VStack(spacing: 8) {
            if appState.todaySessionAccepted {
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
            }
            HStack(spacing: 8) {
                if snapshot.state == .red && !appState.todaySessionAccepted {
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

struct WorkoutSessionView: View {
    let session: PlanSession
    let readiness: ReadinessState

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var readinessService: ReadinessService
    @Environment(\.dismiss) private var dismiss

    @State private var elapsed: Int = 0
    @State private var isSaving = false

    private let startDate = Date()
    private let timerPublisher = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var displayName: String {
        readiness == .red ? "Easy Z2 walk + mobility" : session.name
    }
    private var targetMinutes: Int {
        readiness == .red ? 30 : (readiness == .yellow ? session.durationMin * 4 / 5 : session.durationMin)
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Theme.textMuted)
                    }
                    Spacer()
                    if readiness != .green {
                        StatusTag(text: "Adjusted", tint: Theme.yellow)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)

                Spacer()

                // Timer ring
                ZStack {
                    Circle()
                        .stroke(Theme.card2, lineWidth: 12)
                        .frame(width: 220, height: 220)
                    Circle()
                        .trim(from: 0, to: min(1, CGFloat(elapsed) / CGFloat(targetMinutes * 60)))
                        .stroke(Theme.green, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 220, height: 220)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: elapsed)
                    VStack(spacing: 4) {
                        Text(timeString(elapsed))
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.text)
                        Text("of \(targetMinutes) min")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.textMuted)
                    }
                }

                VStack(spacing: 6) {
                    Text(displayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Theme.text)
                        .multilineTextAlignment(.center)
                    Text(session.kind.emoji + " " + kindLabel)
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textMuted)
                }
                .padding(.top, 28)

                Spacer()

                // Actions
                VStack(spacing: 10) {
                    PrimaryButton(
                        title: isSaving ? "Saving…" : "Mark complete",
                        tint: Theme.green
                    ) {
                        completeWorkout()
                    }
                    .disabled(isSaving)

                    Button("End early — don't log") { dismiss() }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.textMuted)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
        }
        .onReceive(timerPublisher) { _ in elapsed += 1 }
    }

    private var kindLabel: String {
        switch session.kind {
        case .lift: return "Strength training"
        case .run:  return "Cardio"
        case .yoga: return "Yoga & mobility"
        case .rest: return "Recovery"
        }
    }

    private func timeString(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }

    private func completeWorkout() {
        isSaving = true
        let end = Date()
        let activityType: HKWorkoutActivityType = switch session.kind {
            case .lift: .traditionalStrengthTraining
            case .run:  .running
            case .yoga: .yoga
            case .rest: .walking
        }
        let kcalPerMin: Double = switch session.kind {
            case .lift: 7; case .run: 10; case .yoga: 4; case .rest: 3
        }
        let estimatedKcal = Double(elapsed / 60) * kcalPerMin

        Task {
            try? await readinessService.saveWorkout(
                activityType: activityType,
                start: startDate, end: end,
                energyKcal: estimatedKcal > 0 ? estimatedKcal : nil
            )
            appState.acceptTodaySession()
            dismiss()
        }
    }
}

#Preview {
    NavigationStack { TodayView() }
        .environmentObject(AppState())
        .environmentObject(AuthService())
        .environmentObject(ReadinessService())
        .preferredColorScheme(.dark)
}

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

// ─── Data models ──────────────────────────────────────────────────────────────

private struct WorkoutSet: Identifiable {
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

private struct WorkoutExercise: Identifiable {
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
    var weightSummary: String {
        let ws = workingSets.filter(\.isLogged).map { Int($0.weightLbs) }
        guard !ws.isEmpty else { return "" }
        return Set(ws).count == 1 ? "\(ws[0]) lbs" : ws.map { "\($0)" }.joined(separator: "/") + " lbs"
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

private func exerciseCue(for name: String) -> String {
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
    for (k, v) in cues where key.contains(k) { return v }
    return "Focus on controlled movement. Maintain form over load — quality reps drive results."
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
    @State private var exercises: [WorkoutExercise] = []
    @State private var isSaving = false
    @State private var showSummary = false
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
                        }
                        .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 110)
                    }
                    footer
                }
            }
        }
        .onReceive(timerPublisher) { _ in elapsed += 1 }
        .onAppear { if isLift { exercises = buildExercises(from: chips) } }
        .task {
            while !Task.isCancelled {
                if let hr = await readinessService.fetchCurrentHeartRate() { currentHR = hr }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.system(size: 28)).foregroundColor(Theme.textMuted)
            }
            Spacer()
            VStack(spacing: 3) {
                Text(effectiveName).font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.text).lineLimit(1)
                if readiness != .green { StatusTag(text: "Adjusted", tint: Theme.yellow) }
            }
            Spacer()
            Image(systemName: "xmark.circle.fill").font(.system(size: 28)).foregroundColor(.clear)
        }
        .padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 8)
    }

    // MARK: Stats bar

    private var statsBar: some View {
        HStack(spacing: 0) {
            statCell(icon: "heart.fill",  color: Theme.red,    value: currentHR.map { "\($0)" } ?? "—", unit: "bpm")
            Rectangle().fill(Theme.separator).frame(width: 1, height: 44)
            statCell(icon: "flame.fill",  color: Theme.orange, value: "\(kcalBurned)",                  unit: "kcal")
            Rectangle().fill(Theme.separator).frame(width: 1, height: 44)
            statCell(icon: "timer",       color: accentColor,  value: fmt(elapsed),                     unit: "elapsed")
        }
        .padding(.vertical, 14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func statCell(icon: String, color: Color, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundColor(color)
            Text(value).font(.system(size: 20, weight: .bold, design: .monospaced)).foregroundColor(Theme.text)
            Text(unit).font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.textMuted)
                .textCase(.uppercase).tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Lift — exercise accordion

    private var liftContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Exercises")
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.textMuted)
                        .textCase(.uppercase).tracking(0.6)
                    Text("RIR = Reps In Reserve — how many more you could've done")
                        .font(.system(size: 11)).foregroundColor(Theme.textMuted.opacity(0.7))
                }
                Spacer()
                Text("\(exercises.filter(\.isFullyLogged).count) / \(exercises.count)")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.green)
            }

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

    // MARK: Active card (expanded)

    private func activeCard(idx: Int) -> some View {
        let ex = exercises[idx]
        return VStack(alignment: .leading, spacing: 16) {

            // Title + progress
            VStack(alignment: .leading, spacing: 4) {
                let progressLabel: String = {
                    if ex.completedWarmupCount < ex.warmupSets.count {
                        let cur = ex.completedWarmupCount + 1
                        let total = ex.warmupSets.count
                        let working = ex.totalWorkingCount
                        return "Warmup \(cur) of \(total) · then \(working) working sets"
                    } else {
                        let done = ex.completedWorkingCount
                        let total = ex.totalWorkingCount
                        return "Active · \(done) of \(total) working sets done"
                    }
                }()
                Text(progressLabel)
                    .font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.blue)
                    .textCase(.uppercase).tracking(0.5)
                Text(ex.name).font(.system(size: 19, weight: .bold)).foregroundColor(Theme.text)
            }

            // Exercise description / cue
            Text(ex.description)
                .font(.system(size: 13)).foregroundColor(Theme.textMuted)
                .lineSpacing(3).fixedSize(horizontal: false, vertical: true)

            Rectangle().fill(Theme.separator).frame(height: 1)

            // Logged sets history
            if ex.sets.filter(\.isLogged).count > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Completed")
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.textMuted)
                        .textCase(.uppercase).tracking(0.5)
                    ForEach(Array(ex.sets.filter(\.isLogged).enumerated()), id: \.offset) { i, s in
                        let globalIdx = ex.sets.firstIndex(where: { $0.id == s.id }) ?? i
                        loggedSetRow(displayNum: ex.setDisplayNum(at: globalIdx), set: s)
                    }
                }
                Rectangle().fill(Theme.separator).frame(height: 1)
            }

            // RIR picker (set logged, rating pending) — takes priority over input
            if let rirIdx = ex.awaitingRIRIdx {
                rirSection(exIdx: idx, setIdx: rirIdx)
            } else if let nextIdx = ex.nextSetIdx {
                setInputSection(exIdx: idx, setIdx: nextIdx)
            }

            Rectangle().fill(Theme.separator).frame(height: 1)

            // Secondary actions: modify sets, add warmup, skip exercise
            HStack(spacing: 6) {
                modifyActionButton("Add set", icon: "plus.square", color: Theme.blue) {
                    addSet(to: idx)
                }
                modifyActionButton("Remove set", icon: "minus.square", color: Theme.textMuted) {
                    removeLastSet(from: idx)
                }
                .disabled(exercises[idx].workingSets.filter { !$0.isLogged }.count <= 1)

                modifyActionButton("Warmup set", icon: "figure.strengthtraining.traditional", color: Theme.orange) {
                    addWarmupSet(to: idx)
                }

                Spacer()

                modifyActionButton("Skip", icon: "forward.end.fill", color: Theme.red) {
                    skipExercise(idx: idx)
                }
            }
        }
        .padding(18)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(Theme.blue.opacity(0.3), lineWidth: 1.5))
        .animation(.spring(response: 0.35), value: ex.awaitingRIRIdx)
        .animation(.spring(response: 0.35), value: ex.nextSetIdx)
    }

    private func loggedSetRow(displayNum: String, set: WorkoutSet) -> some View {
        HStack(spacing: 0) {
            // Warmup sets shown with orange "W" badge; working sets in muted grey
            Text(displayNum)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(set.isWarmup ? Theme.orange : Theme.textMuted)
                .frame(width: 36, alignment: .leading)
            if set.isWarmup {
                Text("WARM").font(.system(size: 9, weight: .bold))
                    .foregroundColor(Theme.orange).padding(.trailing, 4)
            }
            Text(set.weightLbs > 0 ? "\(Int(set.weightLbs)) lbs" : "BW")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(set.isWarmup ? Theme.textMuted : Theme.text)
            Text(" × ").font(.system(size: 13)).foregroundColor(Theme.textMuted)
            Text("\(set.completedReps) reps")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(set.isWarmup ? Theme.textMuted : Theme.text)
            if !set.isWarmup {
                Text("  (target \(set.targetReps))").font(.system(size: 11)).foregroundColor(Theme.textMuted)
            }
            Spacer()
            if let label = set.rirLabel {
                Text(label).font(.system(size: 11)).foregroundColor(Theme.textMuted)
            } else if !set.isWarmup {
                Text("rate ↓").font(.system(size: 11)).foregroundColor(Theme.yellow)
            }
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(set.isWarmup ? Theme.orange.opacity(0.6) : Theme.green)
                .font(.system(size: 14)).padding(.leading, 8)
        }
    }

    // MARK: Set input (weight + reps + Log button)

    private func setInputSection(exIdx: Int, setIdx: Int) -> some View {
        let ex = exercises[exIdx]
        let set = ex.sets[setIdx]
        return VStack(alignment: .leading, spacing: 14) {
            Group {
                if set.isWarmup {
                    let wNum = ex.sets[..<setIdx].filter(\.isWarmup).count + 1
                    Text("Warmup \(wNum) of \(ex.warmupSets.count)  ·  lighter weight, no RIR needed")
                        .foregroundColor(Theme.orange)
                } else {
                    let wNum = ex.sets[..<setIdx].filter { !$0.isWarmup }.count + 1
                    Text("Set \(wNum) of \(ex.totalWorkingCount)  ·  target \(set.targetReps) reps")
                        .foregroundColor(Theme.textMuted)
                }
            }
            .font(.system(size: 12, weight: .semibold))
            .textCase(.uppercase).tracking(0.5)

            // Weight input — ±5 lb buttons + direct numeric keyboard entry
            HStack(spacing: 0) {
                Button {
                    weightFieldFocused = false
                    withAnimation(.spring(response: 0.2)) {
                        exercises[exIdx].sets[setIdx].weightLbs =
                            max(0, exercises[exIdx].sets[setIdx].weightLbs - 5)
                    }
                } label: {
                    Image(systemName: "minus.circle.fill").font(.system(size: 38))
                        .foregroundColor(set.weightLbs > 0 ? Theme.blue : Theme.card2)
                }
                .disabled(set.weightLbs <= 0)

                Spacer()

                VStack(spacing: 4) {
                    // Tap the number to open the keypad for direct entry
                    let weightBinding = Binding<String>(
                        get: {
                            let w = exercises[exIdx].sets[setIdx].weightLbs
                            return w > 0 ? wStr(w) : ""
                        },
                        set: { str in
                            let cleaned = str.replacingOccurrences(of: ",", with: ".")
                            if let val = Double(cleaned), val >= 0 {
                                exercises[exIdx].sets[setIdx].weightLbs = val
                            } else if str.isEmpty {
                                exercises[exIdx].sets[setIdx].weightLbs = 0
                            }
                        }
                    )
                    TextField("—", text: weightBinding)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.text)
                        .multilineTextAlignment(.center)
                        .frame(minWidth: 80)
                        .focused($weightFieldFocused)
                        #if canImport(UIKit)
                        .keyboardType(.decimalPad)
                        #endif
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") { weightFieldFocused = false }
                                    .fontWeight(.semibold)
                            }
                        }

                    Text("lbs  ·  tap to type  or  ±5")
                        .font(.system(size: 11)).foregroundColor(Theme.textMuted)
                }

                Spacer()

                Button {
                    weightFieldFocused = false
                    withAnimation(.spring(response: 0.2)) {
                        exercises[exIdx].sets[setIdx].weightLbs += 5
                    }
                } label: {
                    Image(systemName: "plus.circle.fill").font(.system(size: 38)).foregroundColor(Theme.blue)
                }
            }
            .padding(.horizontal, 4)

            // Reps stepper
            HStack {
                Text("Completed reps").font(.system(size: 13)).foregroundColor(Theme.textMuted)
                Spacer()
                HStack(spacing: 16) {
                    Button {
                        withAnimation { exercises[exIdx].sets[setIdx].completedReps =
                            max(0, exercises[exIdx].sets[setIdx].completedReps - 1) }
                    } label: {
                        Image(systemName: "minus.circle").font(.system(size: 28)).foregroundColor(Theme.textMuted)
                    }
                    Text("\(exercises[exIdx].sets[setIdx].completedReps)")
                        .font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(Theme.text)
                        .frame(minWidth: 36).contentTransition(.numericText())
                    Button {
                        withAnimation { exercises[exIdx].sets[setIdx].completedReps += 1 }
                    } label: {
                        Image(systemName: "plus.circle").font(.system(size: 28)).foregroundColor(Theme.textMuted)
                    }
                }
            }

            // Log button — warmup sets skip RIR automatically
            let isWarmupSet = exercises[exIdx].sets[setIdx].isWarmup
            let workingNum = exercises[exIdx].sets[..<setIdx].filter { !$0.isWarmup }.count + 1
            let warmupNum2 = exercises[exIdx].sets[..<setIdx].filter { $0.isWarmup }.count + 1
            Button {
                withAnimation(.spring(response: 0.3)) {
                    exercises[exIdx].sets[setIdx].isLogged = true
                    if isWarmupSet {
                        exercises[exIdx].sets[setIdx].rir = 2 // warmup: auto-rate as Good so RIR picker skips
                    }
                }
            } label: {
                Text(isWarmupSet ? "Log warmup W\(warmupNum2)" : "Log set \(workingNum)")
                    .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(isWarmupSet ? Theme.orange : Theme.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    // MARK: RIR rating section

    private func rirSection(exIdx: Int, setIdx: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Rate effort — set \(setIdx + 1)")
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.textMuted)
                    .textCase(.uppercase).tracking(0.5)
                Text("Reps In Reserve (RIR): how many more reps could you have done?")
                    .font(.system(size: 12)).foregroundColor(Theme.textMuted.opacity(0.8))
            }

            HStack(spacing: 6) {
                ForEach(rirOptions, id: \.value) { opt in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            exercises[exIdx].sets[setIdx].rir = opt.value
                            // Pre-fill the next set's weight from the RIR suggestion
                            let next = setIdx + 1
                            if next < exercises[exIdx].sets.count {
                                exercises[exIdx].sets[next].weightLbs = exercises[exIdx].suggestedNextWeight
                            }
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Text(opt.label).font(.system(size: 13, weight: .semibold))
                            Text(opt.subtitle).font(.system(size: 10))
                        }
                        .foregroundColor(opt.color)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(opt.color.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }

            // Load suggestion pill (appears after rating, via parent re-render)
            if let lastLogged = exercises[exIdx].sets.filter({ $0.isLogged && $0.rir != nil }).last {
                let suggestion = loadSuggestionText(for: lastLogged)
                HStack(spacing: 10) {
                    Text(suggestion.text).font(.system(size: 13)).foregroundColor(Theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    if suggestion.proposedWeight > 0 && suggestion.proposedWeight != lastLogged.weightLbs {
                        Button {
                            withAnimation(.spring(response: 0.25)) {
                                let next = setIdx + 1
                                if next < exercises[exIdx].sets.count {
                                    exercises[exIdx].sets[next].weightLbs = suggestion.proposedWeight
                                }
                            }
                        } label: {
                            Text("Apply \(Int(suggestion.proposedWeight)) lbs")
                                .font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.blue)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Theme.blue.opacity(0.15)).clipShape(Capsule())
                        }
                    }
                }
                .padding(12).background(Theme.card2)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Button("Skip rating") {
                withAnimation { exercises[exIdx].sets[setIdx].rir = 2 }
            }
            .font(.system(size: 12)).foregroundColor(Theme.textMuted).frame(maxWidth: .infinity)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func loadSuggestionText(for set: WorkoutSet) -> (text: String, proposedWeight: Double) {
        let w = set.weightLbs
        switch set.rir {
        case .none: return ("Set a weight above to track load", 0)
        case 0:
            let drop = max(0, (w * 0.9 / 2.5).rounded() * 2.5)
            return ("↓  Max effort — drop ~10%, try \(Int(drop)) lbs", drop)
        case 1:
            return ("✓  Challenging — hold at \(Int(w)) lbs", w)
        case 2, 3:
            return ("↑  Solid — add 5 lbs, try \(Int(w + 5)) lbs", w + 5)
        default:
            return ("↑↑  Too easy — add 10 lbs, try \(Int(w + 10)) lbs", w + 10)
        }
    }

    // MARK: Collapsed rows

    private func doneRow(idx: Int) -> some View {
        let ex = exercises[idx]
        let skipped = ex.isSkipped
        return HStack(spacing: 12) {
            Image(systemName: skipped ? "forward.end.fill" : "checkmark.circle.fill")
                .foregroundColor(skipped ? Theme.textMuted : Theme.green)
                .font(.system(size: 20))
            VStack(alignment: .leading, spacing: 2) {
                Text(ex.name).font(.system(size: 14, weight: .semibold))
                    .foregroundColor(skipped ? Theme.textMuted : Theme.text)
                if skipped {
                    Text("Skipped").font(.system(size: 12)).foregroundColor(Theme.textMuted)
                } else {
                    let warmupDone = ex.completedWarmupCount
                    let parts = [
                        warmupDone > 0 ? "\(warmupDone)W warmup" : nil,
                        !ex.weightSummary.isEmpty ? "\(ex.weightSummary) · \(ex.repsSummary)" : nil
                    ].compactMap { $0 }
                    if !parts.isEmpty {
                        Text(parts.joined(separator: " · "))
                            .font(.system(size: 12)).foregroundColor(Theme.textMuted)
                    }
                }
            }
            Spacer()
            if !skipped {
                Text("\(ex.completedWorkingCount) sets").font(.system(size: 12)).foregroundColor(Theme.textMuted)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(skipped ? Theme.card : Theme.green.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func upcomingRow(idx: Int) -> some View {
        let ex = exercises[idx]
        return HStack(spacing: 12) {
            Circle().stroke(Theme.textMuted.opacity(0.4), lineWidth: 1.5).frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(ex.name).font(.system(size: 14, weight: .medium)).foregroundColor(Theme.textMuted)
                Text("\(ex.sets.count) sets · \(ex.sets.first?.targetReps ?? "?") reps")
                    .font(.system(size: 12)).foregroundColor(Theme.textMuted.opacity(0.7))
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    private var footer: some View {
        VStack(spacing: 10) {
            PrimaryButton(title: "Mark complete", tint: Theme.green) {
                withAnimation { showSummary = true }
            }
            Button("End early — don't log") { dismiss() }
                .font(.system(size: 14, weight: .medium)).foregroundColor(Theme.textMuted)
        }
        .padding(.horizontal, 24).padding(.vertical, 16)
        .background(Theme.bg.ignoresSafeArea(edges: .bottom))
    }

    // MARK: Helpers

    private func fmt(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }
    private func wStr(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : String(format: "%.1f", w)
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
            let sets = (0..<setCount).map { _ in WorkoutSet(targetReps: repsStr, completedReps: defaultReps) }
            return WorkoutExercise(name: name, description: exerciseCue(for: name), sets: sets)
        }
    }

    // MARK: Set modification actions

    /// Small labelled icon button used in the secondary action row.
    private func modifyActionButton(_ label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 17))
                Text(label).font(.system(size: 9, weight: .semibold)).multilineTextAlignment(.center)
            }
            .foregroundColor(color)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(color.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
    }

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
        let kcal = met * max(appState.user.weightLb, 100) * 0.453592 * Double(elapsed) / 3600
        Task {
            try? await readinessService.saveWorkout(activityType: activityType, start: startDate, end: end,
                                                     energyKcal: kcal > 1 ? kcal : nil)
            appState.acceptTodaySession()
            dismiss()
        }
    }
}

// MARK: - WorkoutSummaryView

private struct WorkoutSummaryView: View {
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
                                value: totalVolumeLbs > 0 ? "\(totalVolumeLbs)" : "—",
                                label: totalVolumeLbs > 0 ? "lbs total vol." : "Volume",
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
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(ex.name).font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ex.isSkipped ? Theme.textMuted : Theme.text)
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
                            Text(s.weightLbs > 0 ? "\(Int(s.weightLbs)) lbs" : "BW")
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
        .preferredColorScheme(.dark)
}

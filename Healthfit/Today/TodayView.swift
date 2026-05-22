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

private struct WorkoutExercise: Identifiable {
    let id = UUID()
    let name: String
    let sets: Int
    let reps: String            // "6", "8", "AMRAP"
    var completedSets: Int = 0
    var weightLbs: Double = 0
    var pendingRIR: Bool = false // a set was just logged — awaiting RIR rating
    var lastRIR: Int? = nil      // most recent RIR value (0 = failure … 4+ = easy)

    var isFullyLogged: Bool { completedSets >= sets && !pendingRIR }

    // Four discrete RIR options shown in the effort picker
    enum RIROption: Int, CaseIterable {
        case easy = 4   // 4+ reps in reserve
        case good = 2   // 2–3 reps in reserve
        case hard = 1   // 1 rep in reserve
        case max  = 0   // to failure

        var label: String {
            switch self { case .easy: "Easy"; case .good: "Good"; case .hard: "Hard"; case .max: "Max" }
        }
        var subtitle: String {
            switch self { case .easy: "4+ RIR"; case .good: "2–3 RIR"; case .hard: "1 RIR"; case .max: "Failure" }
        }
        var color: Color {
            switch self { case .easy: Theme.blue; case .good: Theme.green; case .hard: Theme.yellow; case .max: Theme.red }
        }
    }

    struct LoadSuggestion {
        let message: String
        let proposedWeight: Double  // 0 = no specific weight (e.g. bodyweight note)
    }

    var loadSuggestion: LoadSuggestion? {
        guard let rir = lastRIR, !pendingRIR else { return nil }
        let w = weightLbs
        switch rir {
        case 0:  // Max — drop ~10%, round to nearest 2.5
            guard w > 0 else { return LoadSuggestion(message: "Set a starting weight to track load", proposedWeight: 0) }
            let drop = max(0, (w * 0.9 / 2.5).rounded() * 2.5)
            return LoadSuggestion(message: "↓  Max effort — drop ~10%, try \(fmtLbs(drop))", proposedWeight: drop)
        case 1:  // Hard — stay
            return LoadSuggestion(message: "✓  Challenging — hold at \(fmtLbs(w))", proposedWeight: w)
        case 2, 3:  // Good — add 5
            return LoadSuggestion(message: "↑  Solid — add 5 lbs, try \(fmtLbs(w + 5))", proposedWeight: w + 5)
        default:  // Easy — add 10
            return LoadSuggestion(message: "↑↑  Too easy — add 10 lbs, try \(fmtLbs(w + 10))", proposedWeight: w + 10)
        }
    }

    private func fmtLbs(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w)) lbs" : String(format: "%.1f lbs", w)
    }
}

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

    private let startDate = Date()
    private let timerPublisher = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isLift: Bool { session.kind == .lift }

    private var effectiveName: String {
        readiness == .red ? "Easy Z2 walk + mobility" : session.name
    }

    private var targetMinutes: Int {
        readiness == .red ? 30 : (readiness == .yellow ? session.durationMin * 4 / 5 : session.durationMin)
    }

    private var kcalBurned: Int {
        let met: Double = switch session.kind {
        case .lift: 5.0; case .run: 9.0; case .yoga: 2.5; case .rest: 3.0
        }
        let weightKg = max(appState.user.weightLb, 100) * 0.453592
        return Int(met * weightKg * Double(elapsed) / 3600.0)
    }

    private var accentColor: Color {
        switch session.kind {
        case .lift: return Theme.orange
        case .run:  return Theme.green
        case .yoga: return Theme.purple
        case .rest: return Theme.textMuted
        }
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        statsBar
                        if isLift { liftContent }
                        else       { cardioContent }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 110)
                }
                footer
            }
        }
        .onReceive(timerPublisher) { _ in elapsed += 1 }
        .onAppear {
            if isLift { exercises = parseExercises(from: chips) }
        }
        .task {
            while !Task.isCancelled {
                if let hr = await readinessService.fetchCurrentHeartRate() {
                    currentHR = hr
                }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Theme.textMuted)
            }
            Spacer()
            VStack(spacing: 3) {
                Text(effectiveName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                if readiness != .green {
                    StatusTag(text: "Adjusted", tint: Theme.yellow)
                }
            }
            Spacer()
            // Mirror for centering
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(.clear)
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: Stats bar — HR · Kcal · Timer

    private var statsBar: some View {
        HStack(spacing: 0) {
            statCell(icon: "heart.fill",  color: Theme.red,
                     value: currentHR.map { "\($0)" } ?? "—", unit: "bpm")
            separator
            statCell(icon: "flame.fill",  color: Theme.orange,
                     value: "\(kcalBurned)", unit: "kcal")
            separator
            statCell(icon: "timer",       color: accentColor,
                     value: timeString(elapsed), unit: "elapsed")
        }
        .padding(.vertical, 14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var separator: some View {
        Rectangle()
            .fill(Theme.separator)
            .frame(width: 1, height: 44)
    }

    private func statCell(icon: String, color: Color, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.text)
            Text(unit)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.textMuted)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Lift content — exercise cards with set tracking

    private var liftContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Exercises")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textMuted)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Text("Set weight · tap dots to log sets · rate effort for load advice")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textMuted.opacity(0.7))
            }

            if exercises.isEmpty {
                Text("See your plan for details.")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ForEach(Array(exercises.indices), id: \.self) { idx in
                    exerciseCard(idx: idx)
                }
            }
        }
    }

    private func exerciseCard(idx: Int) -> some View {
        let ex = exercises[idx]
        return VStack(alignment: .leading, spacing: 14) {

            // ── Name + done badge ──────────────────────────────────────────
            HStack {
                Text(ex.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.text)
                Spacer()
                if ex.isFullyLogged {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            // ── Weight stepper ─────────────────────────────────────────────
            HStack(spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.2)) {
                        exercises[idx].weightLbs = max(0, exercises[idx].weightLbs - 5)
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 34))
                        .foregroundColor(ex.weightLbs > 0 ? Theme.blue : Theme.card2)
                }
                .disabled(ex.weightLbs <= 0)

                Spacer()
                VStack(spacing: 2) {
                    Text(ex.weightLbs > 0 ? weightStr(ex.weightLbs) : "—")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(ex.weightLbs > 0 ? Theme.text : Theme.textMuted)
                        .contentTransition(.numericText())
                    Text("lbs · 5 lb steps")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textMuted)
                }
                Spacer()

                Button {
                    withAnimation(.spring(response: 0.2)) {
                        exercises[idx].weightLbs += 5
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 34))
                        .foregroundColor(Theme.blue)
                }
            }
            .padding(.horizontal, 8)

            Rectangle().fill(Theme.separator).frame(height: 1)

            // ── Set dots ───────────────────────────────────────────────────
            HStack {
                Text("\(ex.sets) sets · \(ex.reps) reps")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textMuted)
                Spacer()
                HStack(spacing: 8) {
                    ForEach(0..<ex.sets, id: \.self) { setIdx in
                        Circle()
                            .fill(setIdx < ex.completedSets ? Theme.green : Color.clear)
                            .overlay(Circle().stroke(
                                setIdx < ex.completedSets ? Theme.green : Theme.textMuted,
                                lineWidth: 2))
                            .frame(width: 30, height: 30)
                            .contentShape(Circle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                    if setIdx < exercises[idx].completedSets {
                                        // Tap a filled dot → undo back to that set
                                        exercises[idx].completedSets = setIdx
                                        exercises[idx].pendingRIR = false
                                        exercises[idx].lastRIR = nil
                                    } else if setIdx == exercises[idx].completedSets {
                                        // Tap the next empty dot → log set, prompt RIR
                                        exercises[idx].completedSets += 1
                                        exercises[idx].pendingRIR = true
                                        exercises[idx].lastRIR = nil
                                    }
                                }
                            }
                    }
                }
            }

            // ── RIR effort picker (shown immediately after logging a set) ──
            if ex.pendingRIR {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rate effort — set \(ex.completedSets)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textMuted)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    HStack(spacing: 6) {
                        ForEach(WorkoutExercise.RIROption.allCases, id: \.rawValue) { option in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    exercises[idx].lastRIR = option.rawValue
                                    exercises[idx].pendingRIR = false
                                }
                            } label: {
                                VStack(spacing: 2) {
                                    Text(option.label)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(option.subtitle)
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(option.color)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(option.color.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // ── Load suggestion (shown after RIR is rated) ─────────────────
            if let sug = ex.loadSuggestion {
                HStack(spacing: 10) {
                    Text(sug.message)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    if sug.proposedWeight > 0 && sug.proposedWeight != ex.weightLbs {
                        Button {
                            withAnimation(.spring(response: 0.25)) {
                                exercises[idx].weightLbs = sug.proposedWeight
                            }
                        } label: {
                            Text("Apply")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Theme.blue.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(12)
                .background(Theme.card2)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .transition(.opacity)
            }
        }
        .padding(16)
        .background(ex.isFullyLogged ? Theme.green.opacity(0.07) : Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(.spring(response: 0.35), value: ex.pendingRIR)
        .animation(.spring(response: 0.35), value: ex.lastRIR)
        .animation(.easeInOut(duration: 0.2), value: ex.isFullyLogged)
    }

    private func weightStr(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : String(format: "%.1f", w)
    }

    // MARK: Cardio / yoga content — circular timer + instruction chips

    private var cardioContent: some View {
        VStack(spacing: 20) {
            // Circular progress ring
            ZStack {
                Circle()
                    .stroke(Theme.card2, lineWidth: 14)
                    .frame(width: 210, height: 210)
                Circle()
                    .trim(from: 0, to: min(1, Double(elapsed) / Double(max(targetMinutes * 60, 1))))
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .frame(width: 210, height: 210)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: elapsed)
                VStack(spacing: 4) {
                    Text(timeString(elapsed))
                        .font(.system(size: 42, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.text)
                    Text("of \(targetMinutes) min")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textMuted)
                }
            }
            .padding(.top, 8)

            // Instruction chips
            if !chips.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Notes")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textMuted)
                        .textCase(.uppercase)
                        .tracking(0.6)
                    ForEach(chips, id: \.self) { chip in
                        HStack(spacing: 10) {
                            Circle().fill(accentColor).frame(width: 6, height: 6)
                            Text(chip)
                                .font(.system(size: 14))
                                .foregroundColor(Theme.text)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 10) {
            PrimaryButton(title: isSaving ? "Saving…" : "Mark complete", tint: Theme.green) {
                completeWorkout()
            }
            .disabled(isSaving)

            Button("End early — don't log") { dismiss() }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.textMuted)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            Theme.bg
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: Helpers

    private func timeString(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }

    /// Parses chips like "Back squat 4×6" into trackable exercises.
    private func parseExercises(from chips: [String]) -> [WorkoutExercise] {
        chips.compactMap { chip in
            guard let xRange = chip.range(of: "×") else { return nil }
            let before = String(chip[..<xRange.lowerBound])
            let parts = before.components(separatedBy: " ")
            guard let sets = Int(parts.last ?? ""), sets > 0 else { return nil }
            let name = parts.dropLast().joined(separator: " ")
            let reps = String(chip[xRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return nil }
            return WorkoutExercise(name: name, sets: sets, reps: reps)
        }
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
        let met: Double = switch session.kind {
        case .lift: 5.0; case .run: 9.0; case .yoga: 2.5; case .rest: 3.0
        }
        let weightKg = max(appState.user.weightLb, 100) * 0.453592
        let estimatedKcal = met * weightKg * Double(elapsed) / 3600.0

        Task {
            try? await readinessService.saveWorkout(
                activityType: activityType,
                start: startDate, end: end,
                energyKcal: estimatedKcal > 1 ? estimatedKcal : nil
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

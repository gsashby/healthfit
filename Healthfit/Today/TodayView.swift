//
//  TodayView.swift
//  Morning briefing. Vitals, score, and reasoning come from ReadinessService
//  (live HealthKit). Workout and nutrition fields are still plan-driven mock
//  data — Phase 3 and 4 will replace those respectively.
//

import SwiftUI

struct TodayView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var readinessService: ReadinessService
    @State private var showSettings = false

    // Merge live HealthKit data into a full ReadinessSnapshot.
    // Workout/nutrition fields still come from MockData until Phase 3/4.
    private var snapshot: ReadinessSnapshot {
        if let live = readinessService.latestData {
            let mock = MockData.readiness(for: live.state)
            return ReadinessSnapshot(
                state: live.state,
                score: live.score,
                vitals: live.vitals,
                workoutTitle: mock.workoutTitle,
                workoutName: mock.workoutName,
                workoutMeta: mock.workoutMeta,
                workoutChips: mock.workoutChips,
                workoutTag: mock.workoutTag,
                reasoning: live.reasoning,
                kcalTarget: mock.kcalTarget,
                macros: mock.macros,
                macroTag: mock.macroTag
            )
        }
        // Fallback: mock data (simulator / no Watch)
        return MockData.readiness(for: appState.readinessState)
    }

    private var isLiveData: Bool { readinessService.latestData != nil }
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
            // Refresh readiness each time the Today tab appears, if already authorized
            if appState.watchConnected {
                await readinessService.fetchReadiness()
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
            PrimaryButton(
                title: snapshot.state == .green ? "Start workout"
                     : snapshot.state == .yellow ? "Accept adjusted plan"
                     : "Accept easy day",
                tint: accent, action: {}
            )
            HStack(spacing: 8) {
                SecondaryButton(title: snapshot.state == .red ? "Full rest day" : "Modify", action: {})
                SecondaryButton(title: snapshot.state == .green ? "Move to tomorrow" : "Keep original", action: {})
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
        ToolbarItem(placement: .topBarLeading) {
            Button { showSettings = true } label: {
                Image(systemName: "gearshape").foregroundColor(Theme.text)
            }
        }
        // Demo mood override — visible in all builds for prototype testing
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Section("Demo · Override readiness") {
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

#Preview {
    NavigationStack { TodayView() }
        .environmentObject(AppState())
        .environmentObject(AuthService())
        .environmentObject(ReadinessService())
        .preferredColorScheme(.dark)
}

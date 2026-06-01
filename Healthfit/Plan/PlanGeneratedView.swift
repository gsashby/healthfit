//
//  PlanGeneratedView.swift
//  The 7-day output: summary, day cards, "how I built this".
//

import SwiftUI

struct PlanGeneratedView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var fmService: FoundationModelService

    @State private var showSwapSheet = false
    @State private var isRegenerating = false
    @State private var regenerateError: String?

    private var plan: WeekPlan { appState.currentPlan }

    private var workoutDayCount: Int { plan.days.filter { !$0.sessions.allSatisfy { $0.kind == .rest } }.count }
    private var liftCount: Int       { plan.days.flatMap(\.sessions).filter { $0.kind == .lift }.count }
    private var runCount: Int        { plan.days.flatMap(\.sessions).filter { $0.kind == .run  }.count }
    private var yogaCount: Int       { plan.days.flatMap(\.sessions).filter { $0.kind == .yoga }.count }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                hero

                if appState.needsNewWeekPlan && plan.weekIndex < plan.totalWeeks {
                    newWeekBanner
                }

                summaryCard

                ForEach(plan.days) { day in
                    DayCard(day: day)
                }

                ReasoningCallout(
                    title: "How I built this.",
                    message: plan.approach,
                    tint: Theme.blue
                )
                .padding(.top, 4)

                actions
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .sheet(isPresented: $showSwapSheet) {
            SwapDaySheet().environmentObject(appState)
        }
    }

    /// "Your week · May 12 – May 18" computed from the current Mon–Sun week
    private var weekRangeLabel: String {
        let cal = Calendar.current
        let today = Date.now
        let weekday = cal.component(.weekday, from: today) // 1=Sun, 2=Mon …
        let daysFromMonday = (weekday == 1) ? 6 : weekday - 2
        guard let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: today),
              let sunday = cal.date(byAdding: .day, value: 6, to: monday) else {
            return "Your week"
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return "Your week · \(fmt.string(from: monday)) – \(fmt.string(from: sunday))"
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(weekRangeLabel)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.blue)
                .textCase(.uppercase)
                .tracking(0.7)
            Text("\(plan.phase) · Week \(plan.weekIndex) of \(plan.totalWeeks)")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(Theme.text)
            Text(plan.summary)
                .font(.system(size: 14))
                .foregroundColor(Theme.textMuted)
                .lineSpacing(2)
                .padding(.top, 2)
                .fixedSize(horizontal: false, vertical: true)

            // Week progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.card2)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.blue)
                        .frame(width: geo.size.width * CGFloat(plan.weekIndex) / CGFloat(max(plan.totalWeeks, 1)),
                               height: 4)
                }
            }
            .frame(height: 4)
            .padding(.top, 4)
        }
    }

    private var newWeekBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar.badge.plus")
                .foregroundColor(Theme.blue)
            Text("Week \(plan.weekIndex + 1) ready — generate your next plan")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.text)
            Spacer()
            Button {
                appState.needsNewWeekPlan = false
                appState.planMode = .input
            } label: {
                Text("Generate")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.blue)
            }
        }
        .padding(14)
        .background(Theme.blue.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This week at a glance")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.text)
                Spacer()
                StatusTag(text: plan.phase, tint: Theme.blue)
            }

            HStack(spacing: 6) {
                stat(n: "\(workoutDayCount)", l: "Active days")
                stat(n: "\(liftCount)",       l: "Lifts")
                stat(n: "\(runCount)",         l: "Runs")
                stat(n: "\(yogaCount)",        l: "Yoga")
            }
        }
        .padding(18)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func stat(n: String, l: String) -> some View {
        VStack(spacing: 2) {
            Text(n)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Theme.blue)
            Text(l)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.textMuted)
                .textCase(.uppercase)
                .tracking(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.card2)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var actions: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                if appState.planLocked {
                    PrimaryButton(title: "Plan locked ✓", tint: Theme.green, action: {})
                        .disabled(true)
                } else {
                    PrimaryButton(title: "Lock in plan", tint: Theme.blue) {
                        appState.lockPlan()
                    }
                }
                SecondaryButton(title: "Swap a day") {
                    showSwapSheet = true
                }
            }

            if !appState.planLocked {
                Button {
                    refreshPlan()
                } label: {
                    HStack(spacing: 6) {
                        if isRegenerating {
                            ProgressView().scaleEffect(0.75).tint(Theme.blue)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(isRegenerating ? "Regenerating…" : "Refresh plan")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.blue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(isRegenerating)

                if let err = regenerateError {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func refreshPlan() {
        guard !isRegenerating else { return }
        regenerateError = nil

        guard fmService.isAvailable else {
            appState.regeneratePlan()
            return
        }

        isRegenerating = true
        Task {
            do {
                let description = appState.lastPlanDescription.isEmpty
                    ? appState.user.description
                    : appState.lastPlanDescription
                // Recompute the goal-context prefix at regen time so the
                // weeks-out countdown stays fresh.
                let prompt = appState.augmentedPlanDescription(description)
                let generated = try await fmService.generateWeekPlan(
                    userDescription: prompt,
                    profile: appState.user,
                    goals: appState.selectedGoals,
                    trainingType: appState.trainingType,
                    strengthSplit: appState.strengthSplit,
                    readinessState: appState.readinessState
                )
                appState.applyGeneratedPlan(generated)
            } catch {
                regenerateError = "Couldn't regenerate — using your existing plan."
                appState.regeneratePlan()
            }
            isRegenerating = false
        }
    }
}

// MARK: - Day card

struct DayCard: View {
    let day: PlanDay

    /// True when day.weekday matches today's actual weekday abbreviation (e.g. "Wed").
    private var isActuallyToday: Bool {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        return fmt.string(from: Date.now) == day.weekday
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Date stamp
            VStack(spacing: 2) {
                Text(day.weekday.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textMuted)
                    .tracking(0.6)
                Text(String(format: "%02d", day.dayNumber))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isActuallyToday ? Theme.blue : Theme.text)
            }
            .frame(width: 44)

            // Body
            VStack(alignment: .leading, spacing: 6) {
                Text(day.tag)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.textMuted)
                    .textCase(.uppercase)
                    .tracking(0.6)

                ForEach(day.sessions) { session in
                    HStack(spacing: 8) {
                        Text(session.kind.emoji)
                            .font(.system(size: 13))
                            .frame(width: 26, height: 26)
                            .background(session.kind.tint.opacity(0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        Text(session.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.text)
                            .lineLimit(1)

                        Spacer()

                        Text("\(session.durationMin) min")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textMuted)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Theme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isActuallyToday ? Theme.blue : .clear, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - SwapDaySheet

struct SwapDaySheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var firstSelection: Int? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(firstSelection == nil
                             ? "Tap a day to select it, then tap another to swap."
                             : "Now tap the day to swap with.")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.textMuted)
                            .padding(.horizontal, 18)
                            .padding(.top, 8)

                        ForEach(Array(appState.currentPlan.days.enumerated()), id: \.offset) { idx, day in
                            swapRow(index: idx, day: day)
                        }
                    }
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Swap a day")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundColor(Theme.green)
                }
            }
        }
    }

    private func swapRow(index: Int, day: PlanDay) -> some View {
        let isSelected = firstSelection == index
        return HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(day.weekday.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textMuted)
                    .tracking(0.6)
                Text(String(format: "%02d", day.dayNumber))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(isSelected ? Theme.blue : Theme.text)
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(day.tag)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textMuted)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text(day.sessions.map(\.name).joined(separator: " · "))
                    .font(.system(size: 14))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Theme.blue)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(isSelected ? Theme.blue.opacity(0.1) : Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 18)
        .contentShape(Rectangle())
        .onTapGesture {
            if let first = firstSelection, first != index {
                appState.swapDays(a: first, b: index)
                firstSelection = nil
            } else {
                firstSelection = isSelected ? nil : index
            }
        }
    }
}

#Preview {
    NavigationStack { PlanGeneratedView() }
        .environmentObject(AppState())
        .environmentObject(FoundationModelService())
        .preferredColorScheme(.dark)
}

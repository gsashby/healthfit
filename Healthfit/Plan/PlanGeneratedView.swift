//
//  PlanGeneratedView.swift
//  The 7-day output: summary, day cards, "how I built this".
//

import SwiftUI

struct PlanGeneratedView: View {
    @EnvironmentObject var appState: AppState

    private var plan: WeekPlan { appState.currentPlan }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                hero
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
            Text("Hybrid plan · Week \(plan.weekIndex) of \(plan.totalWeeks)")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(Theme.text)
            Text(plan.summary)
                .font(.system(size: 14))
                .foregroundColor(Theme.textMuted)
                .lineSpacing(2)
                .padding(.top, 2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This week at a glance")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.text)
                Spacer()
                StatusTag(text: "Hybrid · Cut", tint: Theme.blue)
            }

            HStack(spacing: 6) {
                stat(n: "5", l: "Workouts")
                stat(n: "2", l: "Lifts")
                stat(n: "3", l: "Runs")
                stat(n: "7", l: "Yoga")
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
        HStack(spacing: 8) {
            PrimaryButton(title: "Lock in plan", tint: Theme.blue, action: {})
            SecondaryButton(title: "Swap a day", action: {})
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

#Preview {
    NavigationStack { PlanGeneratedView() }
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}

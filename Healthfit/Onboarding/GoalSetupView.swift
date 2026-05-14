//
//  GoalSetupView.swift
//  Goal picker — one card per high-level goal.
//

import SwiftUI

struct GoalSetupView: View {
    @EnvironmentObject var appState: AppState
    let next: () -> Void

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("Step 3 of 4")
                    .eyebrow()
                    .padding(.top, 16)

                Text("What are you training for?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Theme.text)
                    .padding(.top, 6)

                Text("Pick everything that applies. You can add dates and refine in the Plan tab.")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textMuted)
                    .padding(.top, 6)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(FitnessGoal.allCases) { goal in
                            GoalCard(
                                goal: goal,
                                selected: appState.selectedGoals.contains(goal),
                                tap: {
                                    if appState.selectedGoals.contains(goal) {
                                        appState.selectedGoals.remove(goal)
                                    } else {
                                        appState.selectedGoals.insert(goal)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.top, 22)
                    .padding(.bottom, 12)
                }

                PrimaryButton(
                    title: appState.selectedGoals.isEmpty ? "Pick a goal to continue" : "Continue",
                    tint: appState.selectedGoals.isEmpty ? Theme.card2 : Theme.green
                ) {
                    if !appState.selectedGoals.isEmpty { next() }
                }
                .disabled(appState.selectedGoals.isEmpty)

                Spacer().frame(height: 30)
            }
            .padding(.horizontal, 22)
        }
    }
}

private struct GoalCard: View {
    let goal: FitnessGoal
    let selected: Bool
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack(spacing: 14) {
                Text(goal.emoji)
                    .font(.system(size: 28))
                    .frame(width: 52, height: 52)
                    .background(Theme.card2)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.text)
                    Text(goal.subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textMuted)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(selected ? Theme.green : Theme.textMuted)
            }
            .padding(14)
            .background(Theme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selected ? Theme.green : .clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    GoalSetupView(next: {})
        .environmentObject(AppState())
        .environmentObject(AuthService())
}

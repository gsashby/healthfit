//
//  PlanInputView.swift
//  Free-text + activity pills, parsed-fields preview, generate button.
//

import SwiftUI

struct PlanInputView: View {
    @EnvironmentObject var appState: AppState

    @State private var description: String = MockData.demoUser.description
    @State private var selected: Set<String> = ["Running", "Lifting", "Yoga"]

    private let allActivities = ["Running", "Lifting", "Yoga", "Cycling", "Swimming", "Hiking", "Rowing"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                hero

                inputCard

                parsedCard

                ReasoningCallout(
                    title: "One thing to confirm.",
                    message: "Losing 20 lb while building muscle pulls in opposite directions. I'll prioritize a moderate deficit (~400 kcal/day) with high protein (~1g per lb of lean mass), so muscle is preserved and growth is slow but real. Tap to change.",
                    tint: Theme.blue,
                    iconText: "!"
                )

                VStack(spacing: 8) {
                    PrimaryButton(title: "Generate my week", tint: Theme.blue) {
                        appState.regeneratePlan()
                    }
                    HStack(spacing: 8) {
                        SecondaryButton(title: "Edit details", action: {})
                        SecondaryButton(title: "Use voice", action: {})
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Plan my week")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.blue)
                .textCase(.uppercase)
                .tracking(0.7)

            Text("Tell me what you want\nthis week to look like.")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(Theme.text)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text("Free-form is fine — I'll pull out the goals, constraints, and preferences.")
                .font(.system(size: 14))
                .foregroundColor(Theme.textMuted)
                .lineSpacing(2)
                .padding(.top, 2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Input

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your description").eyebrow()

            // Multiline TextEditor with min height
            TextEditor(text: $description)
                .font(.system(size: 14))
                .foregroundColor(Theme.text)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 130)
                .padding(8)
                .background(Theme.card2)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text("Activities I enjoy").eyebrow()
                .padding(.top, 4)

            FlowLayout(spacing: 6) {
                ForEach(allActivities, id: \.self) { activity in
                    Pill(text: activity, selected: selected.contains(activity)) {
                        if selected.contains(activity) { selected.remove(activity) }
                        else { selected.insert(activity) }
                    }
                }
            }
        }
        .padding(18)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: Parsed

    private var parsedCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What I heard").eyebrow()
                .padding(.bottom, 4)

            ForEach(Array(MockData.parsedInput.enumerated()), id: \.element.id) { index, row in
                HStack(alignment: .top) {
                    Text(row.key)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textMuted)
                    Spacer()
                    Text(row.value)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.text)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.vertical, 10)

                if index < MockData.parsedInput.count - 1 {
                    Rectangle().fill(Theme.separator).frame(height: 1)
                }
            }
        }
        .padding(18)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

#Preview {
    NavigationStack { PlanInputView() }
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}

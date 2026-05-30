//
//  GoalSetupView.swift
//  Training-type picker — up to four sub-steps:
//   1. Training type (single select)
//   2. Days per week
//   3. Priority discipline (hybrid plans only)
//   4. Strength split: Full body | PPL | Upper & lower
//      (shown when training type includes strength)
//

import SwiftUI

struct GoalSetupView: View {
    @EnvironmentObject var appState: AppState
    let next: () -> Void

    private enum SetupStep: Equatable, Hashable {
        case trainingType, daysPerWeek, priority, strengthSplit
    }

    @State private var setupStep: SetupStep = .trainingType
    @State private var selectedType: TrainingType? = nil
    @State private var selectedDays: Int = 4
    @State private var selectedPriority: String? = nil
    @State private var selectedSplit: StrengthSplit? = nil

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("Step 4 of 5")
                    .eyebrow()
                    .padding(.top, 16)

                switch setupStep {
                case .trainingType:
                    trainingTypeView
                case .daysPerWeek:
                    daysPerWeekView
                case .priority:
                    priorityView
                case .strengthSplit:
                    strengthSplitView
                }
            }
            .padding(.horizontal, 22)
        }
        .animation(.easeOut(duration: 0.25), value: setupStep)
    }

    // MARK: - Sub-step 1: Training type

    private var trainingTypeView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Select the type of training you like")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Theme.text)
                .padding(.top, 6)

            Text("This shapes your weekly plan structure.")
                .font(.system(size: 15))
                .foregroundColor(Theme.textMuted)
                .padding(.top, 6)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(TrainingType.allCases) { type in
                        TrainingTypeCard(
                            type: type,
                            selected: selectedType == type,
                            tap: { selectedType = type }
                        )
                    }
                }
                .padding(.top, 22)
                .padding(.bottom, 12)
            }

            PrimaryButton(
                title: selectedType == nil ? "Select a training style to continue" : "Continue",
                tint: selectedType == nil ? Theme.card2 : Theme.green
            ) {
                guard selectedType != nil else { return }
                withAnimation { setupStep = .daysPerWeek }
            }
            .disabled(selectedType == nil)

            Spacer().frame(height: 30)
        }
    }

    // MARK: - Sub-step 2: Days per week

    private var daysPerWeekView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("How many days per week?")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Theme.text)
                .padding(.top, 6)

            Text("We'll build your schedule around this commitment.")
                .font(.system(size: 15))
                .foregroundColor(Theme.textMuted)
                .padding(.top, 6)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
                spacing: 12
            ) {
                ForEach(1...7, id: \.self) { day in
                    DayCountButton(day: day, selected: selectedDays == day) {
                        selectedDays = day
                    }
                }
            }
            .padding(.top, 36)

            Spacer()

            PrimaryButton(title: "Continue", tint: Theme.green) {
                appState.daysPerWeek = selectedDays
                if let type = selectedType {
                    if type.isHybrid {
                        withAnimation { setupStep = .priority }
                    } else if type.includesStrength {
                        withAnimation { setupStep = .strengthSplit }
                    } else {
                        saveAndFinish()
                    }
                }
            }
            .padding(.top, 28)

            Spacer().frame(height: 30)
        }
    }

    // MARK: - Sub-step 3: Priority (hybrid only)

    private var priorityView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What's your priority?")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Theme.text)
                .padding(.top, 6)

            Text("We'll weight your schedule toward this discipline.")
                .font(.system(size: 15))
                .foregroundColor(Theme.textMuted)
                .padding(.top, 6)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(selectedType?.priorityOptions ?? [], id: \.label) { option in
                        PriorityCard(
                            label: option.label,
                            emoji: option.emoji,
                            selected: selectedPriority == option.label,
                            tap: { selectedPriority = option.label }
                        )
                    }
                }
                .padding(.top, 22)
                .padding(.bottom, 12)
            }

            PrimaryButton(
                title: selectedPriority == nil ? "Choose a priority to continue" : "Continue",
                tint: selectedPriority == nil ? Theme.card2 : Theme.green
            ) {
                guard selectedPriority != nil else { return }
                if selectedType?.includesStrength == true {
                    withAnimation { setupStep = .strengthSplit }
                } else {
                    saveAndFinish()
                }
            }
            .disabled(selectedPriority == nil)

            Spacer().frame(height: 30)
        }
    }

    // MARK: - Sub-step 4: Strength split (strength / hybrid-with-strength only)

    private var strengthSplitView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("How do you like to structure your lifts?")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Theme.text)
                .padding(.top, 6)

            Text("This determines how we organise your strength sessions.")
                .font(.system(size: 15))
                .foregroundColor(Theme.textMuted)
                .padding(.top, 6)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(StrengthSplit.allCases) { split in
                        StrengthSplitCard(
                            split: split,
                            selected: selectedSplit == split,
                            tap: { selectedSplit = split }
                        )
                    }
                }
                .padding(.top, 22)
                .padding(.bottom, 12)
            }

            PrimaryButton(
                title: selectedSplit == nil ? "Choose a split to continue" : "Continue",
                tint: selectedSplit == nil ? Theme.card2 : Theme.green
            ) {
                guard selectedSplit != nil else { return }
                saveAndFinish()
            }
            .disabled(selectedSplit == nil)

            Spacer().frame(height: 30)
        }
    }

    // MARK: - Save & advance

    private func saveAndFinish() {
        appState.trainingType = selectedType
        appState.daysPerWeek = selectedDays
        appState.prioritizedDiscipline = selectedPriority
        appState.strengthSplit = selectedSplit
        appState.saveSelectedGoals()
        next()
    }
}

// MARK: - TrainingTypeCard

private struct TrainingTypeCard: View {
    let type: TrainingType
    let selected: Bool
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack(spacing: 14) {
                Text(type.emoji)
                    .font(.system(size: 26))
                    .frame(width: 52, height: 52)
                    .background(Theme.card2)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.text)
                    Text(type.subtitle)
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

// MARK: - DayCountButton

private struct DayCountButton: View {
    let day: Int
    let selected: Bool
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            VStack(spacing: 4) {
                Text("\(day)")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(selected ? Theme.green : Theme.text)
                Text(day == 1 ? "day" : "days")
                    .font(.system(size: 11))
                    .foregroundColor(selected ? Theme.green : Theme.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Theme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? Theme.green : .clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PriorityCard

private struct PriorityCard: View {
    let label: String
    let emoji: String
    let selected: Bool
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack(spacing: 14) {
                Text(emoji)
                    .font(.system(size: 26))
                    .frame(width: 52, height: 52)
                    .background(Theme.card2)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(label)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.text)

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

// MARK: - StrengthSplitCard

private struct StrengthSplitCard: View {
    let split: StrengthSplit
    let selected: Bool
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack(spacing: 14) {
                Text(split.emoji)
                    .font(.system(size: 26))
                    .frame(width: 52, height: 52)
                    .background(Theme.card2)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(split.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.text)
                    Text(split.subtitle)
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

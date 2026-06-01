//
//  PrimaryGoalView.swift
//  Onboarding step 2 — captures the user's primary motivation BEFORE we ask
//  about training mechanics. If they pick "Training for an event", an
//  animated sub-step collects the event name, date, and whether to build a
//  Base → Build → Peak → Taper plan toward that date.
//

import SwiftUI

struct PrimaryGoalView: View {
    @EnvironmentObject var appState: AppState
    let next: () -> Void

    private enum SubStep: Equatable, Hashable {
        case goal, eventDetails
    }

    @State private var subStep: SubStep = .goal
    @State private var selected: PrimaryFitnessGoal? = nil
    @State private var eventName: String = ""
    @State private var eventDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State private var peakPlan: Bool = true

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("Step 2 of 6")
                    .eyebrow()
                    .padding(.top, 16)

                switch subStep {
                case .goal:         goalPicker
                case .eventDetails: eventDetailsForm
                }
            }
            .padding(.horizontal, 22)
        }
        .animation(.easeOut(duration: 0.25), value: subStep)
        .onAppear {
            // Restore in-progress selection if the user backs in mid-flow.
            selected = appState.primaryGoal ?? selected
            eventName = appState.targetEventName.isEmpty ? eventName : appState.targetEventName
            eventDate = appState.targetEventDate ?? eventDate
            peakPlan = appState.wantsPeakPlan
        }
    }

    // MARK: Sub-step 1 — pick the primary goal

    private var goalPicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What's your main goal?")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Theme.text)
                .padding(.top, 6)

            Text("We'll build everything around this — your plan, readiness scoring, and nutrition.")
                .font(.system(size: 15))
                .foregroundColor(Theme.textMuted)
                .padding(.top, 6)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(PrimaryFitnessGoal.allCases) { goal in
                        PrimaryGoalCard(
                            goal: goal,
                            selected: selected == goal,
                            tap: { selected = goal }
                        )
                    }
                }
                .padding(.top, 22)
                .padding(.bottom, 12)
            }

            PrimaryButton(
                title: selected == nil ? "Choose a goal to continue" : "Continue",
                tint: selected == nil ? Theme.card2 : Theme.green
            ) {
                guard let g = selected else { return }
                if g == .eventTraining {
                    withAnimation { subStep = .eventDetails }
                } else {
                    saveAndAdvance()
                }
            }
            .disabled(selected == nil)

            Spacer().frame(height: 30)
        }
    }

    // MARK: Sub-step 2 — event details (only when "Training for an event" is picked)

    private var eventDetailsForm: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Tell us about your event")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Theme.text)
                    .padding(.top, 6)

                Text("We'll structure your training toward this date.")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textMuted)
                    .padding(.top, 6)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    Text("What's the event?").eyebrow()
                    TextField("e.g. Boston Marathon, sprint triathlon", text: $eventName)
                        #if canImport(UIKit)
                        .textInputAutocapitalization(.words)
                        #endif
                        .autocorrectionDisabled(false)
                        .font(.system(size: 16))
                        .foregroundColor(Theme.text)
                        .padding(14)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.top, 24)

                VStack(alignment: .leading, spacing: 6) {
                    Text("When is it?").eyebrow()
                    DatePicker(
                        "Event date",
                        selection: $eventDate,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(Theme.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.top, 18)

                PeakPlanToggleCard(isOn: $peakPlan)
                    .padding(.top, 18)

                PrimaryButton(
                    title: canContinueFromEvent ? "Continue" : "Add event details to continue",
                    tint: canContinueFromEvent ? Theme.green : Theme.card2
                ) {
                    guard canContinueFromEvent else { return }
                    saveAndAdvance()
                }
                .disabled(!canContinueFromEvent)
                .padding(.top, 24)

                Button("Back") {
                    withAnimation { subStep = .goal }
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

                Spacer().frame(height: 30)
            }
        }
    }

    private var canContinueFromEvent: Bool {
        !eventName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: Save & advance

    private func saveAndAdvance() {
        appState.primaryGoal = selected
        if selected == .eventTraining {
            appState.targetEventName = eventName.trimmingCharacters(in: .whitespaces)
            appState.targetEventDate = eventDate
            appState.wantsPeakPlan = peakPlan
        } else {
            appState.targetEventName = ""
            appState.targetEventDate = nil
            appState.wantsPeakPlan = true
        }
        appState.savePrimaryGoal()
        next()
    }
}

// MARK: - PrimaryGoalCard

private struct PrimaryGoalCard: View {
    let goal: PrimaryFitnessGoal
    let selected: Bool
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack(spacing: 14) {
                Text(goal.emoji)
                    .font(.system(size: 26))
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

// MARK: - PeakPlanToggleCard

private struct PeakPlanToggleCard: View {
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundColor(isOn ? Theme.green : Theme.textMuted)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Build a peak-performance plan toward this date")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.text)
                        .multilineTextAlignment(.leading)
                    Text("Healthfit will structure your training in phases: Base → Build → Peak → Taper")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textMuted)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .background(Theme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isOn ? Theme.green : .clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PrimaryGoalView(next: {})
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}

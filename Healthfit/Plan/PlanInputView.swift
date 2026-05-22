//
//  PlanInputView.swift
//  Free-text input + activity pills. "Generate my week" calls
//  FoundationModelService to parse intent and build a real WeekPlan.
//  Falls back to MockData when Apple Intelligence is unavailable.
//

import SwiftUI

struct PlanInputView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var fmService: FoundationModelService

    @State private var description: String = ""
    @State private var selected: Set<String> = ["Running", "Lifting", "Yoga"]
    @State private var parsedRows: [ParsedInput] = MockData.parsedInput
    @State private var isParsing = false
    @State private var isGenerating = false
    @State private var errorMessage: String?

    private let allActivities = ["Running", "Lifting", "Yoga", "Cycling", "Swimming", "Hiking", "Rowing"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                hero
                inputCard
                parsedCard
                if !fmService.isAvailable {
                    unavailableBanner
                }
                actionButtons
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .onAppear {
            if description.isEmpty {
                description = appState.user.description.isEmpty
                    ? MockData.demoUser.description
                    : appState.user.description
            }
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Plan my week")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.blue)
                    .textCase(.uppercase)
                    .tracking(0.7)
                Spacer()
                if fmService.isAvailable {
                    Label("Apple Intelligence", systemImage: "apple.intelligence")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.blue)
                }
            }
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

    // MARK: Input card

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your description").eyebrow()
            TextEditor(text: $description)
                .font(.system(size: 14))
                .foregroundColor(Theme.text)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 130)
                .padding(8)
                .background(Theme.card2)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text("Activities I enjoy").eyebrow().padding(.top, 4)
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

    // MARK: Parsed card

    private var parsedCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("What I heard").eyebrow()
                Spacer()
                if isParsing {
                    ProgressView().scaleEffect(0.7).tint(Theme.blue)
                }
            }
            .padding(.bottom, 4)

            ForEach(Array(parsedRows.enumerated()), id: \.element.id) { index, row in
                HStack(alignment: .top) {
                    Text(row.key).font(.system(size: 13)).foregroundColor(Theme.textMuted)
                    Spacer()
                    Text(row.value).font(.system(size: 13)).foregroundColor(Theme.text)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.vertical, 10)
                if index < parsedRows.count - 1 {
                    Rectangle().fill(Theme.separator).frame(height: 1)
                }
            }
        }
        .padding(18)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: Unavailable banner

    private var unavailableBanner: some View {
        ReasoningCallout(
            title: "Apple Intelligence not available.",
            message: "Plan generation requires iPhone 15 Pro or later with iOS 18.1+. " +
                     "Using your existing plan in the meantime.",
            tint: Theme.yellow,
            iconText: "!"
        )
    }

    // MARK: Action buttons

    private var actionButtons: some View {
        VStack(spacing: 8) {
            if let err = errorMessage {
                Text(err).font(.system(size: 13)).foregroundColor(Theme.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            PrimaryButton(
                title: isGenerating ? "Generating your plan…" : "Generate my week",
                tint: Theme.blue
            ) {
                generatePlan()
            }
            .disabled(isGenerating)
            HStack(spacing: 8) {
                SecondaryButton(title: "Edit details", action: {})
                SecondaryButton(title: "Use voice", action: {})
            }
        }
        .padding(.top, 4)
    }

    // MARK: Actions

    private func generatePlan() {
        guard !isGenerating else { return }
        errorMessage = nil
        guard fmService.isAvailable else {
            appState.regeneratePlan()
            return
        }
        isGenerating = true
        Task {
            do {
                isParsing = true
                if let parsed = try? await fmService.parseInput(description) {
                    parsedRows = buildParsedRows(from: parsed)
                }
                isParsing = false
                let generated = try await fmService.generateWeekPlan(
                    userDescription: description,
                    profile: appState.user,
                    goals: appState.selectedGoals,
                    readinessState: appState.readinessState
                )
                appState.applyGeneratedPlan(generated)
            } catch {
                isParsing = false
                errorMessage = error.localizedDescription
                appState.regeneratePlan()
            }
            isGenerating = false
        }
    }

    private func buildParsedRows(from parsed: ParsedUserInput) -> [ParsedInput] {
        var rows: [ParsedInput] = []
        if !parsed.goals.isEmpty {
            rows.append(ParsedInput(key: "Goals", value: parsed.goals.joined(separator: " · ")))
        }
        if !parsed.preferredActivities.isEmpty {
            rows.append(ParsedInput(key: "Modalities", value: parsed.preferredActivities.joined(separator: " + ")))
        }
        rows.append(ParsedInput(key: "Workout length", value: "~\(parsed.sessionLengthMinutes) min"))
        if !parsed.otherConstraints.isEmpty {
            rows.append(ParsedInput(key: "Other", value: parsed.otherConstraints.first ?? ""))
        }
        return rows
    }
}

#Preview {
    NavigationStack { PlanInputView() }
        .environmentObject(AppState())
        .environmentObject(FoundationModelService())
        .preferredColorScheme(.dark)
}

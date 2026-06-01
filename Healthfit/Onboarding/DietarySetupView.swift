//
//  DietarySetupView.swift
//  Onboarding step 3 of 5 — captures allergies and dietary preferences.
//  All selections are optional; the user can skip entirely.
//

import SwiftUI

struct DietarySetupView: View {
    @EnvironmentObject var appState: AppState
    let next: () -> Void

    private static let allergyOptions = [
        "Dairy", "Eggs", "Gluten", "Tree nuts",
        "Peanuts", "Soy", "Shellfish", "Fish",
    ]
    private static let preferenceOptions = [
        "High-protein", "Low-carb", "Vegetarian", "Vegan",
        "Dairy-free", "Gluten-free", "Keto", "Paleo",
    ]

    @State private var selectedAllergies: Set<String> = []
    @State private var selectedPreferences: Set<String> = []

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Step 4 of 6").eyebrow().padding(.top, 16)

                    Text("Any dietary needs?")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Theme.text)
                        .padding(.top, 6)

                    Text("We'll flag your allergens in food suggestions and tailor nutrition guidance.")
                        .font(.system(size: 15))
                        .foregroundColor(Theme.textMuted)
                        .padding(.top, 6)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    // MARK: Allergies

                    Text("Allergies").eyebrow().padding(.top, 28)

                    FlowLayout(spacing: 8) {
                        ForEach(Self.allergyOptions, id: \.self) { option in
                            Pill(
                                text: option,
                                selected: selectedAllergies.contains(option),
                                tint: Theme.red
                            ) {
                                if selectedAllergies.contains(option) {
                                    selectedAllergies.remove(option)
                                } else {
                                    selectedAllergies.insert(option)
                                }
                            }
                        }
                    }
                    .padding(.top, 10)

                    // MARK: Preferences

                    Text("Preferences").eyebrow().padding(.top, 24)

                    FlowLayout(spacing: 8) {
                        ForEach(Self.preferenceOptions, id: \.self) { option in
                            Pill(
                                text: option,
                                selected: selectedPreferences.contains(option),
                                tint: Theme.green
                            ) {
                                if selectedPreferences.contains(option) {
                                    selectedPreferences.remove(option)
                                } else {
                                    selectedPreferences.insert(option)
                                }
                            }
                        }
                    }
                    .padding(.top, 10)

                    PrimaryButton(title: "Continue", tint: Theme.green) {
                        save()
                        next()
                    }
                    .padding(.top, 32)

                    Button("Skip for now") { next() }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 14)

                    Spacer().frame(height: 30)
                }
                .padding(.horizontal, 22)
            }
        }
        .onAppear {
            // Pre-populate if user returns to onboarding or edits via Settings.
            selectedAllergies = Set(appState.dietaryProfile.allergies)
            selectedPreferences = Set(appState.dietaryProfile.preferences)
        }
    }

    private func save() {
        appState.dietaryProfile = DietaryProfile(
            allergies: Array(selectedAllergies).sorted(),
            preferences: Array(selectedPreferences).sorted(),
            dislikes: appState.dietaryProfile.dislikes
        )
        appState.saveDietaryProfile()
    }
}

#Preview {
    DietarySetupView(next: {})
        .environmentObject(AppState())
}

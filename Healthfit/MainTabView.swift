//
//  MainTabView.swift
//  Tab container for the main app. Today / Plan / Eat / Coach.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            NavigationStack { TodayView() }
                .tabItem { Label("Today", systemImage: "sun.max.fill") }

            NavigationStack { PlanView() }
                .tabItem { Label("Plan",  systemImage: "calendar") }

            NavigationStack { FoodView() }
                .tabItem { Label("Eat",   systemImage: "leaf.fill") }

            NavigationStack { CoachPlaceholder() }
                .tabItem { Label("Coach", systemImage: "bubble.left.and.bubble.right.fill") }
        }
        .tint(Theme.green)
    }
}

/// Stub for the AI coach tab. The fourth flow is intentionally not built —
/// the prototype is testing the first three. Long-press resets onboarding
/// so testers can re-run the first-time experience.
struct CoachPlaceholder: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 44))
                    .foregroundColor(Theme.textMuted)
                Text("Coach Chat")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Theme.text)
                Text("Coming in the next prototype iteration.")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textMuted)

                Text("Long-press to reset onboarding")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textMuted.opacity(0.6))
                    .padding(.top, 30)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 0.6) {
                        appState.resetOnboarding()
                    }
            }
        }
    }
}

// MARK: - SettingsView

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var age = ""
    @State private var sex = "Male"
    @State private var weight = ""
    @State private var goalWeight = ""
    @State private var showDeleteConfirm = false
    private let sexOptions = ["Male", "Female", "Other"]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        sectionLabel("Profile")
                        VStack(spacing: 12) {
                            ProfileField(label: "Name", placeholder: "Your first name", text: $name)
                            ProfileField(label: "Age", placeholder: "e.g. 32", text: $age, keyboard: .numberPad)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Sex at birth").eyebrow()
                                Picker("Sex", selection: $sex) {
                                    ForEach(sexOptions, id: \.self) { Text($0).tag($0) }
                                }.pickerStyle(.segmented)
                            }
                            ProfileField(label: "Current weight (lbs)", placeholder: "e.g. 185", text: $weight, keyboard: .decimalPad)
                            ProfileField(label: "Goal weight (lbs)", placeholder: "e.g. 165", text: $goalWeight, keyboard: .decimalPad)
                        }
                        PrimaryButton(title: "Save changes", tint: Theme.green) {
                            appState.saveUserProfile(UserProfile(
                                name: name.trimmingCharacters(in: .whitespaces),
                                age: Int(age) ?? appState.user.age,
                                sexAtBirth: sex,
                                weightLb: Double(weight) ?? appState.user.weightLb,
                                goalWeightLb: Double(goalWeight) ?? appState.user.goalWeightLb,
                                description: appState.user.description))
                            dismiss()
                        }
                        sectionLabel("Account").padding(.top, 8)
                        Button {
                            authService.signOut(); appState.resetOnboarding()
                        } label: {
                            Text("Sign out").font(.system(size: 16, weight: .semibold)).foregroundColor(Theme.text)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Theme.card2).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }.buttonStyle(.plain)
                        Button { showDeleteConfirm = true } label: {
                            Text("Delete account").font(.system(size: 16, weight: .semibold)).foregroundColor(Theme.red)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Theme.red.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }.buttonStyle(.plain)
                    }
                    .padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 40)
                }
            }
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.foregroundColor(Theme.green) } }
            .alert("Delete account?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) { authService.signOut(); appState.resetOnboarding() }
                Button("Cancel", role: .cancel) {}
            } message: { Text("This will erase all your data and cannot be undone.") }
        }
        .onAppear {
            name = appState.user.name; sex = appState.user.sexAtBirth
            age = appState.user.age == 0 ? "" : "\(appState.user.age)"
            weight = appState.user.weightLb == 0 ? "" : "\(Int(appState.user.weightLb))"
            goalWeight = appState.user.goalWeightLb == 0 ? "" : "\(Int(appState.user.goalWeightLb))"
        }
    }

    private func sectionLabel(_ t: String) -> some View {
        Text(t).font(.system(size: 18, weight: .bold)).foregroundColor(Theme.text)
    }
}

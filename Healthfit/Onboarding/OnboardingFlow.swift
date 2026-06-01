//
//  OnboardingFlow.swift
//  Seven-screen onboarding (six numbered steps + a welcome screen):
//   0: WelcomeView          — no step badge
//   1: SignUpView           — "Step 1 of 6"  (skipped if already authenticated)
//   2: PrimaryGoalView      — "Step 2 of 6"  (the "why" — comes BEFORE mechanics)
//   3: ProfileSetupView     — "Step 3 of 6"
//   4: DietarySetupView     — "Step 4 of 6"
//   5: GoalSetupView        — "Step 5 of 6"  (training type, days, split)
//   6: ConnectWatchView     — "Step 6 of 6"
//

import SwiftUI
import AuthenticationServices

struct OnboardingFlow: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @State private var step: Int = 0

    var body: some View {
        ZStack {
            switch step {
            case 0: WelcomeView(next: advance)
            case 1: SignUpView(next: advance)
            case 2: PrimaryGoalView(next: advance)
            case 3: ProfileSetupView(next: advance)
            case 4: DietarySetupView(next: advance)
            case 5: GoalSetupView(next: advance)
            default: ConnectWatchView(next: finish)
            }
        }
        .animation(.easeOut(duration: 0.25), value: step)
        .onAppear {
            // If already authenticated (returning user), skip the sign-up step
            // and land directly on the primary-goal screen.
            if authService.isAuthenticated && step == 0 {
                step = 2
            }
        }
    }

    private func advance() {
        step += 1
    }

    private func finish() {
        appState.saveSelectedGoals()
        // Immediately swap the default mock plan for one that matches the user's
        // chosen split, so Today and Plan tabs are correct before they generate a
        // real AI plan.
        appState.regeneratePlan()
        appState.completeOnboarding()
    }
}

// MARK: - SignUpView

struct SignUpView: View {
    @EnvironmentObject var authService: AuthService
    let next: () -> Void
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Text("Step 1 of 6").eyebrow().padding(.top, 16)
                Text("Create your account")
                    .font(.system(size: 28, weight: .bold)).foregroundColor(Theme.text).padding(.top, 6)
                Text("Your data stays on your device.")
                    .font(.system(size: 15)).foregroundColor(Theme.textMuted)
                    .padding(.top, 6).lineSpacing(3).fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 12) {
                    SignInWithAppleButton(.signUp,
                        onRequest: { $0.requestedScopes = [.fullName, .email] },
                        onCompletion: {
                            if authService.handleAppleSignIn($0) { next() }
                        })
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    divider
                    AuthFieldLocal(placeholder: "Email", text: $email, isSecure: false)
                    AuthFieldLocal(placeholder: "Password (8+ characters)", text: $password, isSecure: true)
                    if let err = errorMessage {
                        Text(err).font(.system(size: 13)).foregroundColor(Theme.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding(.top, 28)

                Spacer()
                PrimaryButton(title: isLoading ? "Creating account…" : "Continue", tint: Theme.green) {
                    attempt { try authService.signUp(email: email, password: password); next() }
                }
                .disabled(isLoading)
                Spacer().frame(height: 30)
            }.padding(.horizontal, 22)
        }
    }

    private var divider: some View {
        HStack {
            Rectangle().fill(Theme.separator).frame(height: 1)
            Text("or").font(.system(size: 13)).foregroundColor(Theme.textMuted).padding(.horizontal, 8)
            Rectangle().fill(Theme.separator).frame(height: 1)
        }.padding(.vertical, 4)
    }

    private func attempt(_ block: () throws -> Void) {
        errorMessage = nil; isLoading = true
        do { try block() } catch let e as AuthError { errorMessage = e.errorDescription }
          catch { errorMessage = error.localizedDescription }
        isLoading = false
    }
}

// MARK: - ProfileSetupView

struct ProfileSetupView: View {
    @EnvironmentObject var appState: AppState
    let next: () -> Void
    @State private var name = ""
    @State private var age = ""
    @State private var sex = "Male"
    @State private var weight = ""
    @State private var goalWeight = ""
    private let sexOptions = ["Male", "Female", "Other"]
    private var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        Int(age) != nil && Double(weight) != nil && Double(goalWeight) != nil
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Step 3 of 6").eyebrow().padding(.top, 16)
                    Text("Tell us about you")
                        .font(.system(size: 28, weight: .bold)).foregroundColor(Theme.text).padding(.top, 6)
                    Text("Used to personalise your plan, readiness scoring, and nutrition targets.")
                        .font(.system(size: 15)).foregroundColor(Theme.textMuted)
                        .padding(.top, 6).lineSpacing(3).fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 14) {
                        ProfileField(label: "Name", placeholder: "Your first name", text: $name)
                        #if canImport(UIKit)
                        ProfileField(label: "Age", placeholder: "e.g. 32", text: $age, keyboard: .numberPad)
                        #else
                        ProfileField(label: "Age", placeholder: "e.g. 32", text: $age)
                        #endif
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Sex at birth").eyebrow()
                            Picker("Sex", selection: $sex) {
                                ForEach(sexOptions, id: \.self) { Text($0).tag($0) }
                            }.pickerStyle(.segmented)
                        }
                        #if canImport(UIKit)
                        ProfileField(label: "Current weight (\(appState.useMetric ? "kg" : "lbs"))", placeholder: appState.useMetric ? "e.g. 84" : "e.g. 185", text: $weight, keyboard: .decimalPad)
                        ProfileField(label: "Goal weight (\(appState.useMetric ? "kg" : "lbs"))", placeholder: appState.useMetric ? "e.g. 75" : "e.g. 165", text: $goalWeight, keyboard: .decimalPad)
                        #else
                        ProfileField(label: "Current weight (\(appState.useMetric ? "kg" : "lbs"))", placeholder: appState.useMetric ? "e.g. 84" : "e.g. 185", text: $weight)
                        ProfileField(label: "Goal weight (\(appState.useMetric ? "kg" : "lbs"))", placeholder: appState.useMetric ? "e.g. 75" : "e.g. 165", text: $goalWeight)
                        #endif
                    }.padding(.top, 24)

                    PrimaryButton(
                        title: canContinue ? "Continue" : "Fill in your details to continue",
                        tint: canContinue ? Theme.green : Theme.card2
                    ) {
                        guard canContinue else { return }
                        appState.saveUserProfile(UserProfile(
                            name: name.trimmingCharacters(in: .whitespaces),
                            age: Int(age) ?? 0, sexAtBirth: sex,
                            weightLb: appState.storedWeightLbs(Double(weight) ?? 0),
                            goalWeightLb: appState.storedWeightLbs(Double(goalWeight) ?? 0),
                            description: ""))
                        next()
                    }
                    .disabled(!canContinue)
                    .padding(.top, 28)
                    Spacer().frame(height: 30)
                }.padding(.horizontal, 22)
            }
        }
    }
}

// MARK: - Private auth text field (local to this file)

private struct AuthFieldLocal: View {
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    var body: some View {
        Group {
            if isSecure { SecureField(placeholder, text: $text) }
            else {
                TextField(placeholder, text: $text)
                    #if canImport(UIKit)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
            }
        }
        .font(.system(size: 16)).foregroundColor(Theme.text)
        .padding(14).background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    OnboardingFlow()
        .environmentObject(AppState())
        .environmentObject(AuthService())
}

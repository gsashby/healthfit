//
//  AppState.swift
//  Single observable for the prototype. Holds auth, onboarding status, the current
//  user, the active plan, and demo controls (mood toggle, plan view mode).
//
//  When wiring real data:
//   - Replace `readinessSnapshot` with a HealthKit-backed publisher.
//   - Replace `currentPlan` with a server-fetched plan keyed by user.
//   - The email/password auth is local Keychain only (prototype). A real backend
//     would verify credentials server-side.
//

import Foundation
import SwiftUI
import AuthenticationServices
import Security
import SwiftData

// MARK: - AuthService

@MainActor
final class AuthService: NSObject, ObservableObject {
    @Published var isAuthenticated: Bool = false
    private let service = "com.healthfit.auth"

    override init() {
        super.init()
        restoreSession()
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        guard case .success(let auth) = result,
              let cred = auth.credential as? ASAuthorizationAppleIDCredential else { return }
        keychainSave("userID", value: cred.user)
        keychainSave("method", value: "apple")
        isAuthenticated = true
    }

    func signUp(email: String, password: String) throws {
        guard !email.isEmpty, password.count >= 8 else { throw AuthError.invalidCredentials }
        keychainSave("userID", value: email)
        keychainSave("method", value: "email")
        keychainSave("email", value: email)
        isAuthenticated = true
    }

    func signIn(email: String, password: String) throws {
        guard let stored = keychainRead("email"), stored == email, !password.isEmpty else {
            throw AuthError.noAccountFound
        }
        isAuthenticated = true
    }

    func signOut() {
        ["userID", "method", "email"].forEach { keychainDelete($0) }
        isAuthenticated = false
    }

    private func restoreSession() {
        guard let id = keychainRead("userID") else { return }
        if keychainRead("method") == "apple" {
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: id) { [weak self] state, _ in
                Task { @MainActor [weak self] in
                    self?.isAuthenticated = state == .authorized
                    if state != .authorized { self?.signOut() }
                }
            }
        } else {
            isAuthenticated = true
        }
    }

    private func keychainSave(_ key: String, value: String) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service,
                                kSecAttrAccount as String: key,
                                kSecValueData as String: value.data(using: .utf8)!]
        SecItemDelete(q as CFDictionary)
        SecItemAdd(q as CFDictionary, nil)
    }

    private func keychainRead(_ key: String) -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service,
                                kSecAttrAccount as String: key,
                                kSecReturnData as String: true,
                                kSecMatchLimit as String: kSecMatchLimitOne]
        var r: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &r) == errSecSuccess,
              let d = r as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    private func keychainDelete(_ key: String) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service,
                                kSecAttrAccount as String: key]
        SecItemDelete(q as CFDictionary)
    }
}

// MARK: - AuthError

enum AuthError: LocalizedError {
    case invalidCredentials, noAccountFound
    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Enter a valid email and a password of 8+ characters."
        case .noAccountFound: return "No account found with that email. Please sign up."
        }
    }
}

// MARK: - AppState

@MainActor
final class AppState: ObservableObject {

    // MARK: Onboarding — backed by UserDefaults so they load synchronously (no UI flash)

    @Published var hasOnboarded: Bool = UserDefaults.standard.bool(forKey: "hasOnboarded")
    @Published var watchConnected: Bool = UserDefaults.standard.bool(forKey: "watchConnected")

    // MARK: Selected goals

    @Published var selectedGoals: Set<FitnessGoal> = []

    // MARK: User & plan

    @Published var user: UserProfile = UserProfile(
        name: "", age: 0, sexAtBirth: "Male",
        weightLb: 0, goalWeightLb: 0, description: "")
    @Published var currentPlan: WeekPlan = MockData.hybridWeek

    // MARK: Demo controls

    /// The simulated readiness state, toggled from the Today view's
    /// developer affordance. In production this would come from HealthKit.
    @Published var readinessState: ReadinessState = .green

    /// Plan tab view mode (input vs generated).
    @Published var planMode: PlanMode = .generated

    var readinessSnapshot: ReadinessSnapshot {
        MockData.readiness(for: readinessState)
    }

    // MARK: SwiftData

    private var modelContext: ModelContext?

    func configure(with context: ModelContext) {
        modelContext = context
        loadFromStore()
    }

    private func loadFromStore() {
        guard let ctx = modelContext else { return }
        let descriptor = FetchDescriptor<PersistedProfile>()
        guard let profile = try? ctx.fetch(descriptor).first else { return }
        user = profile.asUserProfile
        selectedGoals = profile.selectedGoals
    }

    func saveUserProfile(_ profile: UserProfile) {
        user = profile
        persistToStore()
    }

    func saveSelectedGoals() {
        persistToStore()
    }

    private func persistToStore() {
        guard let ctx = modelContext else { return }
        let descriptor = FetchDescriptor<PersistedProfile>()
        let existing = try? ctx.fetch(descriptor)
        let record: PersistedProfile
        if let first = existing?.first {
            record = first
        } else {
            record = PersistedProfile()
            ctx.insert(record)
        }
        record.name = user.name
        record.age = user.age
        record.sexAtBirth = user.sexAtBirth
        record.weightLb = user.weightLb
        record.goalWeightLb = user.goalWeightLb
        record.planDescription = user.description
        record.selectedGoalIDs = selectedGoals.map(\.rawValue)
        record.hasOnboarded = hasOnboarded
        record.watchConnected = watchConnected
        try? ctx.save()
    }

    private func clearStore() {
        guard let ctx = modelContext else { return }
        let descriptor = FetchDescriptor<PersistedProfile>()
        if let profiles = try? ctx.fetch(descriptor) {
            profiles.forEach { ctx.delete($0) }
            try? ctx.save()
        }
    }

    // MARK: - Actions

    func completeOnboarding() {
        hasOnboarded = true
        UserDefaults.standard.set(true, forKey: "hasOnboarded")
        persistToStore()
    }

    func resetOnboarding() {
        hasOnboarded = false
        watchConnected = false
        selectedGoals = []
        user = UserProfile(name: "", age: 0, sexAtBirth: "Male",
                           weightLb: 0, goalWeightLb: 0, description: "")
        UserDefaults.standard.set(false, forKey: "hasOnboarded")
        UserDefaults.standard.set(false, forKey: "watchConnected")
        clearStore()
    }

    func setWatchConnected(_ connected: Bool) {
        watchConnected = connected
        UserDefaults.standard.set(connected, forKey: "watchConnected")
        persistToStore()
    }

    /// Falls back to the mock hybrid week (used when FM is unavailable).
    func regeneratePlan() {
        currentPlan = MockData.hybridWeek
        planMode = .generated
    }

    /// Converts a Foundation Models GeneratedPlan into a WeekPlan and applies it.
    func applyGeneratedPlan(_ generated: GeneratedPlan) {
        let calendar = Calendar.current
        let today = Date()
        // Anchor to the Monday of the current week
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!

        let days: [PlanDay] = generated.days.prefix(7).enumerated().map { offset, genDay in
            let date = calendar.date(byAdding: .day, value: offset, to: monday)!
            let dayNumber = calendar.component(.day, from: date)
            let isToday = calendar.isDateInToday(date)

            let sessions: [PlanSession] = genDay.sessions.map { s in
                let kind: SessionKind = switch s.kind.lowercased() {
                    case "lift":  .lift
                    case "run":   .run
                    case "yoga":  .yoga
                    default:      .rest
                }
                return PlanSession(kind: kind, name: s.name, durationMin: s.durationMin)
            }
            return PlanDay(weekday: genDay.weekday, dayNumber: dayNumber,
                           tag: genDay.tag, isToday: isToday, sessions: sessions)
        }

        currentPlan = WeekPlan(
            weekIndex: currentPlan.weekIndex,
            totalWeeks: currentPlan.totalWeeks,
            phase: currentPlan.phase,
            days: days,
            summary: generated.summary,
            approach: generated.approach
        )
        planMode = .generated
    }
}

// MARK: - PlanMode

enum PlanMode: String, CaseIterable, Identifiable {
    case input = "Input"
    case generated = "Generated"
    var id: String { rawValue }
}

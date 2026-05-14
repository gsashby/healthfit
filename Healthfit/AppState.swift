//
//  AppState.swift
//  Single observable for the prototype. Holds onboarding status, the current
//  user, the active plan, and demo controls (mood toggle, plan view mode).
//
//  When wiring real data:
//   - Replace `readinessSnapshot` with a HealthKit-backed publisher.
//   - Replace `currentPlan` with a server-fetched plan keyed by user.
//

import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {

    // MARK: Onboarding

    @Published var hasOnboarded: Bool = false
    @Published var selectedGoals: Set<FitnessGoal> = []
    @Published var watchConnected: Bool = false

    // MARK: User & plan

    @Published var user: UserProfile = MockData.demoUser
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

    // MARK: - Actions

    func completeOnboarding() {
        withAnimation(.easeOut(duration: 0.3)) {
            hasOnboarded = true
        }
    }

    func resetOnboarding() {
        hasOnboarded = false
        selectedGoals = []
        watchConnected = false
    }

    /// Simulates regenerating a plan after the user edits inputs.
    /// In production, this would call into a plan-generation service.
    func regeneratePlan() {
        currentPlan = MockData.hybridWeek
        planMode = .generated
    }
}

enum PlanMode: String, CaseIterable, Identifiable {
    case input = "Input"
    case generated = "Generated"
    var id: String { rawValue }
}

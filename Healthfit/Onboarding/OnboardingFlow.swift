//
//  OnboardingFlow.swift
//  Three-step onboarding: Welcome → Goal → Connect Watch.
//

import SwiftUI

struct OnboardingFlow: View {
    @EnvironmentObject var appState: AppState
    @State private var step: Int = 0

    var body: some View {
        ZStack {
            switch step {
            case 0: WelcomeView(next: advance)
            case 1: GoalSetupView(next: advance)
            default: ConnectWatchView(next: finish)
            }
        }
        .animation(.easeOut(duration: 0.25), value: step)
    }

    private func advance() {
        step += 1
    }

    private func finish() {
        appState.completeOnboarding()
    }
}

#Preview {
    OnboardingFlow().environmentObject(AppState())
}

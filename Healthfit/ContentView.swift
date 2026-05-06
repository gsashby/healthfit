//
//  ContentView.swift
//  Root: routes between onboarding and the main tab view.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            if appState.hasOnboarded {
                MainTabView()
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                OnboardingFlow()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.35), value: appState.hasOnboarded)
    }
}

#Preview {
    ContentView().environmentObject(AppState())
}

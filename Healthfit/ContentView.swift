//
//  ContentView.swift
//  Root: routes between onboarding and the main tab view based on auth + onboarding state.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            if authService.isAuthenticated && appState.hasOnboarded {
                MainTabView()
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                OnboardingFlow()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.35), value: authService.isAuthenticated && appState.hasOnboarded)
        .task {
            appState.configure(with: modelContext)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(AuthService())
}

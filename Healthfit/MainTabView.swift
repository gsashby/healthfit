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

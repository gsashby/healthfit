//
//  HealthFitApp.swift
//  HealthFit Prototype
//
//  App entry point.
//

import SwiftUI
import SwiftData

@main
struct HealthFitApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authService = AuthService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(authService)
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: PersistedProfile.self)
    }
}

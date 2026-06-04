//
//  HealthFitApp.swift
//  HealthFit Prototype
//
//  App entry point.
//

import SwiftUI
import SwiftData
import UserNotifications

// MARK: - Notification delegate

final class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    /// Show banner + sound even when the app is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handler([.banner, .sound])
    }

    /// Deep-link to the correct tab when the user taps a notification.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler handler: @escaping () -> Void) {
        let tab: Int
        switch response.notification.request.identifier {
        case "healthfit.morning-readiness", "healthfit.workout-reminder": tab = 0
        case "healthfit.nutrition-nudge": tab = 2
        default: tab = 0
        }
        NotificationCenter.default.post(name: .healthfitSwitchTab, object: tab)
        handler()
    }
}

extension Notification.Name {
    static let healthfitSwitchTab = Notification.Name("healthfit.switchTab")
}

// MARK: - App

@main
struct HealthFitApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authService = AuthService()
    @StateObject private var readinessService = ReadinessService()
    @StateObject private var fmService = FoundationModelService()

    private let notificationDelegate = AppNotificationDelegate()

    static var isScreenshotMode: Bool {
        CommandLine.arguments.contains("--screenshots")
    }

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        CrashReporter.configure()

        if Self.isScreenshotMode {
            // Inject demo state so the app launches straight into the main UI
            // with realistic content for App Store screenshots.
            let d = UserDefaults.standard
            d.set(true,           forKey: "hasOnboarded")
            d.set(true,           forKey: "watchConnected")
            d.set(true,           forKey: "planLocked")
            d.set("Gerald",       forKey: "userName")
            d.set(50,             forKey: "userAge")
            d.set("Male",         forKey: "userSex")
            d.set(198.0,          forKey: "userWeightLb")
            d.set(178.0,          forKey: "userGoalWeightLb")
        }
    }

    // Called once AppState is ready — wires Watch sync callback.
    // Using onAppear on the root view to avoid SwiftUI init-order issues.
    private func setupServices() {
        appState.setupWatchSync()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(authService)
                .environmentObject(readinessService)
                .environmentObject(fmService)
                .preferredColorScheme(.dark)
                .onAppear {
                    appState.advanceWeekIfNeeded()
                    setupServices()
                }
                .onReceive(NotificationCenter.default.publisher(for: .healthfitSwitchTab)) { note in
                    if let tab = note.object as? Int {
                        appState.selectedTab = tab
                    }
                }
        }
        .modelContainer(for: PersistedProfile.self)
    }
}

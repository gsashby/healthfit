//
//  CrashReporter.swift
//  Crash reporting initialisation point.
//
//  Currently a no-op. To wire in a real provider, add its SDK as a Swift
//  Package and replace CrashReporter.configure() below.
//
//  Recommended providers:
//  • Sentry (open-source, generous free tier)
//    https://github.com/getsentry/sentry-cocoa
//    Setup: SentrySDK.start { $0.dsn = "YOUR-DSN"; $0.tracesSampleRate = 0.2 }
//
//  • Firebase Crashlytics
//    Requires GoogleService-Info.plist in the Xcode target.
//    Setup: FirebaseApp.configure()  (Crashlytics starts automatically)
//
//  Call CrashReporter.configure() once in HealthFitApp.init() before any
//  other code runs.
//

import Foundation

enum CrashReporter {

    /// Call once at app startup, before the SwiftUI scene is created.
    static func configure() {
        // Replace with your provider's initialisation call.
        // Example for Sentry:
        //   SentrySDK.start { options in
        //       options.dsn = "YOUR-SENTRY-DSN"
        //       options.tracesSampleRate = 0.2
        //       options.environment = isProduction ? "production" : "debug"
        //   }
        #if DEBUG
        print("[CrashReporter] No crash reporter configured — add Sentry or Crashlytics SDK.")
        #endif
    }

    /// Attach extra context that appears alongside crash reports.
    static func setUser(id: String, name: String) {
        // Example for Sentry:
        //   let user = SentrySDK.currentUser() ?? User()
        //   user.userId = id; user.username = name
        //   SentrySDK.setUser(user)
        _ = id; _ = name
    }

    /// Manually capture a non-fatal error (e.g. a failed HealthKit query).
    static func capture(_ error: Error, context: String? = nil) {
        // Example for Sentry:
        //   SentrySDK.capture(error: error) { scope in
        //       if let ctx = context { scope.setTag(value: ctx, key: "context") }
        //   }
        #if DEBUG
        print("[CrashReporter] Non-fatal: \(context ?? "") — \(error)")
        #endif
    }
}

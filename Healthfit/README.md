# HealthFit — SwiftUI Prototype

An interactive iOS prototype of the adaptive fitness & nutrition coach. Covers the four user-tested flows: **Onboarding**, **Today / Morning Briefing**, **Plan My Week** (input + generated), and **Food / Nutrition**.

This is a prototype, not production code — all data is mocked. HealthKit and HKWorkoutSession integrations are stubbed so the UI can be tested without entitlements.

## Setup (5 minutes)

1. Open Xcode (16+ recommended).
2. **File → New → Project → iOS → App**.
   - Product Name: `HealthFit`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **None**
3. Close the new project's auto-created `ContentView.swift` and `HealthFitApp.swift`.
4. In Finder, drag every `.swift` file from this folder (and its subfolders) into the Xcode project navigator. When prompted, **check "Copy items if needed"** and add to the `HealthFit` target.
5. Build & run on the iPhone 15 simulator. iOS 17+ deployment target.

## Project layout

```
HealthFitPrototype/
├── README.md                  ← you are here
├── HealthFitApp.swift         App entry point
├── ContentView.swift          Root: routes to onboarding or main tab view
├── AppState.swift             ObservableObject: user, plan, readiness, demo controls
├── Theme.swift                Colors, typography, common modifiers
├── Models.swift               User, Goal, Plan, Day, Workout, Readiness, Food
├── MockData.swift             All simulated HRV/sleep/plans/foods
├── Components.swift           Reusable: PrimaryButton, SecondaryButton, Chip, Pill
├── MainTabView.swift          Bottom tab container
├── Onboarding/
│   ├── OnboardingFlow.swift
│   ├── WelcomeView.swift
│   ├── GoalSetupView.swift
│   └── ConnectWatchView.swift
├── Today/
│   └── TodayView.swift        Morning briefing
├── Plan/
│   ├── PlanView.swift         Container, switches input/output
│   ├── PlanInputView.swift
│   └── PlanGeneratedView.swift
└── Food/
    └── FoodView.swift         Macros + meals + photo-log mock
```

## Demo controls

The prototype has a hidden demo bar — pull down on the Today view to expose Green / Caution / Red mood toggles. The Plan tab has Input / Generated states accessible from a segmented control. Onboarding can be re-triggered from the Coach tab placeholder (long-press Reset).

## What's mocked vs what's real

| Surface | Status |
|---|---|
| UI / navigation | Real SwiftUI |
| HRV, sleep, RHR | Mocked in `MockData.swift` |
| Plan generation | Static templates keyed by goal in `MockData.swift` |
| Food database | Sample list in `MockData.swift` |
| HealthKit | Not wired — see `// TODO: HealthKit` in `AppState.swift` |
| Apple Watch app | Not built — phone-only for v1 of the prototype |
| Backend | None — fully on-device |

## Next steps after testing

If feedback is positive, the highest-leverage swaps are: (1) wire `HKHealthStore` queries for HRV/sleep so readiness reflects real overnight data, and (2) replace the static plan templates with a server-side generator that the input view calls.

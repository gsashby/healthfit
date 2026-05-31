# HealthFit — Architecture Reference

## Overview

HealthFit is a SwiftUI iOS app (+ watchOS companion) that provides daily readiness-driven training, nutrition tracking, and AI coaching. All AI runs on-device via Apple Foundation Models. No user data leaves the device except for the USDA food search API.

**Deployment target:** iOS 18.1+ (Apple Intelligence required for AI features; all features degrade gracefully without it)  
**Language:** Swift 5.9+  
**UI framework:** SwiftUI  
**Persistence:** SwiftData + UserDefaults  
**AI:** Apple Foundation Models (`FoundationModels` framework)  
**Health data:** HealthKit  
**Watch:** watchOS companion via WatchConnectivity  

---

## File Structure

```
Healthfit/
├── HealthFitApp.swift              App entry point — injects all environment objects
├── ContentView.swift               Root router: onboarding vs main tab view
├── AppState.swift                  Central observable — user, plan, readiness, food log
│                                   Also contains: AuthService, WatchConnectivityService
├── FoundationModelService.swift    All Apple Foundation Models calls
├── ReadinessService.swift          HealthKit reads → readiness score calculation
├── MockData.swift                  Split-aware fallback plans; readiness snapshots
├── Models.swift                    All data models and SwiftData @Model
├── Components.swift                Reusable UI: PrimaryButton, Pill, ReasoningCallout, etc.
├── Theme.swift                     Design system: colours, modifiers, eyebrow text style
├── MainTabView.swift               Tab container + CoachView + SettingsView
│
├── Onboarding/
│   ├── OnboardingFlow.swift        Step router (0–5); also SignUpView, ProfileSetupView
│   ├── WelcomeView.swift           Step 0 (no badge) + SignInView sheet
│   ├── DietarySetupView.swift      Step 3 of 5 — allergens + preferences
│   ├── GoalSetupView.swift         Step 4 of 5 — training type, days, priority, split
│   └── ConnectWatchView.swift      Step 5 of 5 — HealthKit authorization
│
├── Today/
│   └── TodayView.swift             Morning briefing, workout card, nudge cards
│                                   Also contains: WorkoutSessionView, WorkoutSummaryView
│
├── Plan/
│   ├── PlanView.swift              Tab container; switches input ↔ generated
│   ├── PlanInputView.swift         Free-text + activity pills → FM generation
│   └── PlanGeneratedView.swift     7-day output, swap day sheet, refresh button
│
├── Food/
│   ├── FoodView.swift              Macro ring, meal list, FAB menu
│                                   Also: PhotoLogSheet, EditEntrySheet, FoodEntryForm
│   ├── FoodDatabaseService.swift   USDA FoodData Central API service
│   ├── FoodSearchView.swift        Search UI + SearchResultSheet (serving picker)
│   ├── CameraFoodRecognizer.swift  UIImagePickerController + VNClassifyImageRequest
│   ├── BarcodeScannerView.swift    DataScannerViewController + Open Food Facts API
│   └── OpenFoodFactsService.swift  Open Food Facts API service
│
├── Healthfit/                      Xcode asset catalog (app icon, etc.)
│
├── HealthfitWatch/                 watchOS companion app
│   ├── HealthfitWatchApp.swift
│   ├── WatchConnectivityReceiver.swift
│   ├── WatchRootView.swift
│   └── WatchWorkoutDetailView.swift
│
├── HealthfitTests/                 Unit test stubs (empty)
└── HealthfitUITests/               UI test stubs (empty)
```

---

## Core Data Flow

```
HealthKit ──► ReadinessService ──► AppState.readinessState
                                        │
                                        ▼
                               adjustedTodayWorkout()
                                   ├─► TodayView (snapshot)
                                   └─► FoodView (macro targets)

User input ──► PlanInputView ──► FoundationModelService.generateWeekPlan()
                                        │
                                        ▼
                               AppState.currentPlan (WeekPlan)
                                   ├─► TodayView (today's session)
                                   ├─► PlanGeneratedView (7-day view)
                                   └─► WorkoutSessionView (live session)

Food log ──► AppState.todayFoodLog ──► FoodView (eaten totals)
                                   └─► TodayView (nudge card)

AppState ──► WatchConnectivityService ──► watchOS companion
```

---

## AppState

`AppState` is a `@MainActor final class ObservableObject` — the single source of truth for all mutable app state. Every view reaches it via `@EnvironmentObject`.

### Key published properties

| Property | Type | Purpose |
|---|---|---|
| `hasOnboarded` | `Bool` | Controls root routing in ContentView |
| `watchConnected` | `Bool` | Whether HealthKit is authorized |
| `user` | `UserProfile` | Name, age, sex, weight, goal weight |
| `trainingType` | `TrainingType?` | Onboarding selection (strength, running, hybrid…) |
| `strengthSplit` | `StrengthSplit?` | Full body / PPL / Upper-lower |
| `daysPerWeek` | `Int` | Weekly training volume |
| `dietaryProfile` | `DietaryProfile` | Allergies, preferences, dislikes |
| `currentPlan` | `WeekPlan` | Active 7-day plan |
| `readinessState` | `ReadinessState` | Demo override (.green/.yellow/.red) |
| `todayFoodLog` | `[FoodEntry]` | Today's logged meals |
| `selectedGoals` | `Set<FitnessGoal>` | Legacy goal flags (still used by FM prompt) |
| `needsNewWeekPlan` | `Bool` | Triggers week-rollover UI |
| `planMode` | `PlanMode` | Input vs generated view in Plan tab |
| `planLocked` | `Bool` | Prevents accidental plan overwrites |
| `todaySessionAccepted` | `Bool` | Workout logged state |
| `lastPlanDescription` | `String` | Persisted for plan refresh |

### Key methods

| Method | Purpose |
|---|---|
| `adjustedTodayWorkout(readiness:)` | Returns session name, chips, kcal, macros adjusted for readiness |
| `logFood(_:)` / `removeFoodEntry(id:)` / `updateFoodEntry(_:)` | Food log CRUD |
| `regeneratePlan()` | Loads split-appropriate mock when FM unavailable |
| `applyGeneratedPlan(_:)` | Converts `GeneratedPlan` → `WeekPlan` with real dates |
| `lockPlan()` / `advanceWeekIfNeeded()` | Plan lifecycle |
| `saveDietaryProfile()` / `saveSelectedGoals()` | Trigger SwiftData persistence |
| `syncToWatch(readiness:score:)` | Sends today's workout to watch via WatchConnectivity |

---

## Persistence Architecture

### SwiftData — `PersistedProfile`

Single `@Model` object storing the full user profile. Loaded via `configure(with: ModelContext)` called from `HealthFitApp` after the model container is ready.

Fields: name, age, sex, weight, goalWeight, planDescription, selectedGoalIDs, hasOnboarded, watchConnected, trainingTypeID, daysPerWeek, prioritizedDiscipline, strengthSplitID, dietaryAllergies, dietaryPreferences, dietaryDislikes.

### UserDefaults

| Key | Value | TTL |
|---|---|---|
| `hasOnboarded` | `Bool` | Permanent |
| `watchConnected` | `Bool` | Permanent |
| `planLocked` | `Bool` | Permanent |
| `lastPlanDescription` | `String` | Permanent |
| `weekStartDate` | `Date` | Permanent |
| `foodLog_yyyy-MM-dd` | `[FoodEntry]` JSON | Auto-expires (key changes daily) |

---

## AI Architecture (Foundation Models)

All AI runs on-device via `FoundationModels` framework. `FoundationModelService` is a `@MainActor final class ObservableObject`.

**Important:** Foundation Models cannot handle concurrent `LanguageModelSession` instances. All FM calls in `TodayView.task` run sequentially.

### Sessions

| Session | Type | Lifecycle |
|---|---|---|
| `coachSession` | Persistent | Lives for the app session; reset on `resetCoachSession()` |
| Plan generation | Per-call | Fresh session each `generateWeekPlan` call |
| Reasoning enhance | Per-call | Fresh session |
| Coach nudge | Per-call | Fresh session |
| Week summary | Per-call | Fresh session |

### Methods

| Method | Input | Output |
|---|---|---|
| `generateWeekPlan(...)` | Profile, goals, training type, strength split, readiness | `GeneratedPlan` (structured) |
| `parseInput(_:)` | Free text | `ParsedUserInput` (structured) |
| `streamCoachReply(to:context:)` | Message + context | `AsyncThrowingStream<String>` |
| `enhanceReadinessReasoning(_:userName:state:)` | Rule-based reasoning + name | Personalised string |
| `generateCoachNudge(...)` | Nutrition stats + session kind | One-sentence nudge |
| `generateWeekSummary(...)` | Week index, phase, name | 1–2 sentence summary |

---

## Onboarding Flow (5 steps)

```
Step 0 — WelcomeView (no badge)
Step 1 — SignUpView "Step 1 of 5" (skipped if authenticated)
Step 2 — ProfileSetupView "Step 2 of 5" (name, age, sex, weight)
Step 3 — DietarySetupView "Step 3 of 5" (allergies, preferences)
Step 4 — GoalSetupView "Step 4 of 5" (up to 4 sub-steps):
          • Training type (7 options)
          • Days per week (1–7)
          • Priority discipline (hybrid types only)
          • Strength split (Full body / PPL / Upper-lower; strength types only)
Step 5 — ConnectWatchView "Step 5 of 5" (HealthKit authorization)

On finish: saveSelectedGoals() → regeneratePlan() → completeOnboarding()
```

---

## Strength Split → Plan Generation Pipeline

User selection flows through every layer:

1. **Onboarding** — `GoalSetupView` saves `appState.strengthSplit`
2. **Mock fallback** — `MockData.plan(trainingType:strengthSplit:)` returns a split-appropriate 7-day mock
3. **AI prompt** — `generateWeekPlan` injects `split.planDescription` + split-specific naming instructions
4. **Exercise chips** — `AppState.liftChips(sessionName:)` returns split-correct exercises regardless of AI session naming
5. **Yellow-readiness chips** — append `(−20% load)` to each chip

---

## Food Logging Pipeline

```
User taps "Log food"
    ├─► "Search food database" → FoodSearchView → USDA API → SearchResultSheet (serving picker) → logFood()
    ├─► "Scan barcode" → BarcodeScannerView → Open Food Facts API → SearchResultSheet → logFood()
    └─► "Scan with camera" → CameraPickerView → VNClassifyImageRequest → FoodSearchView(initialQuery:) → logFood()

Manual: PhotoLogSheet → FoodEntryForm → logFood()
Edit:   MealRow (swipe left) → EditEntrySheet → FoodEntryForm → updateFoodEntry()
Delete: MealRow (swipe right, full swipe) → removeFoodEntry(id:)

All entries: AppState.todayFoodLog → UserDefaults (foodLog_yyyy-MM-dd)
```

---

## Watch Companion

The watchOS companion receives today's workout payload via `WatchConnectivity.updateApplicationContext`:

```swift
WatchWorkoutPayload {
    workoutName, workoutMeta, exercises: [String],
    readinessState, readinessScore, readinessLabel,
    kcalTarget, isAdjusted
}
```

`WatchRootView` displays the readiness score and workout summary. `WatchWorkoutDetailView` shows the exercise list. `WatchConnectivityReceiver` handles incoming payloads on the watch side.

---

## Design System (`Theme.swift`)

| Token | Usage |
|---|---|
| `Theme.bg` | Screen backgrounds |
| `Theme.card` / `Theme.card2` | Card surfaces (two levels) |
| `Theme.text` / `Theme.textMuted` | Primary / secondary text |
| `Theme.green` | Primary action, positive states |
| `Theme.blue` | Plan tab, secondary actions |
| `Theme.orange` | Lift sessions, fat macro |
| `Theme.red` | Alerts, allergens, destructive |
| `Theme.yellow` | Warnings, moderate readiness |
| `Theme.purple` | Coach nudge |
| `Theme.separator` | Dividers |

`Theme.accent(for: ReadinessState)` and `Theme.accentSoft(for:)` return the appropriate tint for the current readiness.

The `.eyebrow()` modifier applies the standard uppercase tracking label style used throughout the app.

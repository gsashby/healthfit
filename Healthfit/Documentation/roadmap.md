# HealthFit — Product Roadmap

## Current State

HealthFit is a functional prototype with four tabs (Today, Plan, Eat, Coach) and a three-step onboarding flow. The UI, design system, and navigation are complete. All data is driven by `MockData.swift` — no persistence, no live APIs, no real HealthKit reads. The goal of this roadmap is to replace every mock with production-grade functionality, one phase at a time.

---

## Phase 1 — Foundation (Pre-requisite for everything else)

These items must land before any other phase can deliver real value.

### 1.1 Authentication
- Implement Apple Sign In (required for App Store) and email/password sign-up
- Wire the "I already have an account" button on `WelcomeView` to a sign-in screen
- Secure token storage in Keychain
- Session persistence across launches — app should skip onboarding if a session exists

### 1.2 User Profile Persistence
- Capture age, weight, goal weight, sex, and dietary preferences during onboarding (currently hardcoded in `MockData.demoUser`)
- Store the completed `UserProfile` and `selectedGoals` (now a `Set<FitnessGoal>`) to persistent storage
- Add a Settings / Profile screen to let users edit these values post-onboarding

### 1.3 Local Persistence Layer
- Introduce SwiftData (or CoreData) to replace all `MockData` references
- Entities needed: `UserProfile`, `WeekPlan`, `PlanDay`, `FoodEntry`, `DayNutrition`
- `AppState` should load from the store on launch and write back on mutation

### 1.4 Real Date & Time
- Replace all hardcoded date strings ("Wednesday · April 29", "Today · April 29", "Apr 27 – May 3") with computed values derived from the current calendar date
- `PlanDay.dayNumber` and `PlanDay.isToday` should reflect real dates, not demo fixtures

---

## Phase 2 — HealthKit Integration

The app's core value proposition — daily readiness-driven adjustments — requires real biometric data.

### 2.1 HealthKit Authorization
- Replace the simulated `connect()` delay in `ConnectWatchView` with a real `HKHealthStore.requestAuthorization` call
- Request read permissions for: HRV (SDNN), sleep analysis (stages), resting heart rate, active energy, workouts
- Persist `watchConnected` state so the authorization step isn't repeated

### 2.2 Readiness Score Calculation
- Build a `ReadinessService` that reads last night's HRV, sleep duration/score, and resting HR from HealthKit
- Calculate a readiness score (0–100) and map it to `ReadinessState` (.green / .yellow / .red)
- Replace `AppState.readinessState` (currently a manual demo toggle) with the service output
- Remove the demo mood menu from `TodayView` toolbar once real data flows

### 2.3 Background HealthKit Delivery
- Register for HealthKit background delivery so the app recalculates readiness overnight while the user sleeps
- Schedule a local notification to deliver the morning briefing when readiness is ready

### 2.4 Workout Sync
- Write completed workouts back to HealthKit after a session ends
- Read historical workouts to inform plan adaptation (training load, consistency)

---

## Phase 3 — AI Plan Generation

Currently "Generate my week" calls `appState.regeneratePlan()` which just reloads the same static `MockData.hybridWeek`.

### 3.1 NLP Input Parsing ✅ (implemented — Apple Foundation Models)
- `FoundationModelService.parseInput(_:)` extracts goals, modalities, session length, and constraints from free-text using `@Generable` structured output
- The "What I heard" card updates live with the parsed result

### 3.2 Plan Generation Service ✅ (implemented — Apple Foundation Models)
- `FoundationModelService.generateWeekPlan(...)` produces a `GeneratedPlan` using on-device Foundation Models — no backend, fully private
- `AppState.applyGeneratedPlan(_:)` converts the `GeneratedPlan` → `WeekPlan` with real calendar dates
- "Generate my week" shows a loading state and populates `AppState.currentPlan`
- Falls back to MockData when Apple Intelligence is unavailable

### 3.3 Readiness-Driven Daily Adjustment
- Each morning, compare today's readiness score against the planned session's load
- Auto-adjust the session (reduce intensity, swap to recovery) when readiness is yellow or red
- The "As planned" / "Adjusted" tag on the workout card should reflect whether an adjustment was made and why

### 3.4 Plan Actions
- Wire "Lock in plan" to persist the accepted `WeekPlan` to the local store
- Wire "Swap a day" to open a session picker and write the change back
- Wire "Start workout", "Accept adjusted plan", "Accept easy day" to begin a tracked workout session
- Wire "Move to tomorrow" and "Keep original" to update the plan accordingly

### 3.5 Multi-Week Progression
- Track week index across a full training block (e.g., 12 weeks)
- Auto-generate the next week's plan at week rollover
- Show progress through the block on the Plan tab header

---

## Phase 4 — Nutrition

The Eat tab UI is solid but entirely static. `FoodView` reads directly from `MockData.dayNutrition`.

### 4.1 Food Database Integration ✅ (implemented)
- `FoodDatabaseService` queries the USDA FoodData Central API (free DEMO_KEY; swap for a registered key at fdc.nal.usda.gov for production rate limits)
- Parses nutrient IDs 1008/1003/1005/1004 (energy, protein, carbs, fat) from search results; scales per-100g values to the food's serving size
- 0.5 s debounce cancels in-flight requests on each keystroke; graceful error state for network failures
- `FoodSearchView` — full-screen NavigationStack sheet with a live search bar, lazy result rows (name, brand, kcal, macros, serving size), and empty/loading/error states
- `SearchResultSheet` — serving picker (0.5× increments with animated numericText), live macro summary that updates as servings change, meal-type segmented picker (auto-seeded by time of day)
- "Log food" FAB in `FoodView` is now a `Menu` offering "Search food database" (new) and "Scan with camera" (existing photo log)

### 4.2 Real Food Logging ✅ (implemented)
- `FoodEntry` and `Macros` are now `Codable`; today's log persisted to UserDefaults keyed by date (auto-resets next day)
- `AppState` owns `todayFoodLog: [FoodEntry]` with `logFood(_:)`, `removeFoodEntry(id:)`, and `loadFoodLog()` (called on launch via `configure(with:)`)
- `FoodView.nutrition` computes `kcalEaten`, `macroEaten`, and `entries` from the real log — macro ring and bars are live
- Empty state shown when no food is logged yet
- Swipe-to-delete on any logged meal row
- `PhotoLogSheet` — tapping a suggestion creates and logs a `FoodEntry` (kcal + allergens from mock; macros deferred to 4.1); includes a meal-type segmented picker auto-seeded from time of day
- `PhotoLogSheet` — "None of these — type it" opens an inline `ManualEntryView` form (name required, kcal required, carbs/protein/fat optional)

### 4.3 Photo-Based Food Recognition
- Replace the simulated camera scan with a real AVFoundation camera capture
- Use the Vision framework or a food recognition API (Clarifai, LogMeal) to identify food in the image
- Return real matches instead of the hardcoded `MockData.foodPickerSuggestions`

### 4.4 Dietary Profile Capture ✅ (implemented)
- New onboarding step 3 of 5 (`DietarySetupView`) captures allergies (Dairy, Eggs, Gluten, Tree nuts, Peanuts, Soy, Shellfish, Fish) and preferences (High-protein, Low-carb, Vegetarian, Vegan, Dairy-free, Gluten-free, Keto, Paleo) via multi-select pills; skippable
- `SettingsView` gains a "Dietary profile" section so users can edit selections post-onboarding
- `DietaryProfile` persisted to SwiftData via `PersistedProfile`
- `MealRow` highlights allergen tags red and adds a ⚠ banner when a logged meal contains a user allergen; card background tints red
- `PhotoLogSheet` food suggestions apply the same allergen highlighting so users know before they log

### 4.5 Macro Targets from Plan Context ✅ (implemented)
- `FoodView` now derives kcal and macro targets from `appState.adjustedTodayWorkout(readiness:)`, which computes targets based on today's session type (lift/run/rest) and the current readiness state
- The "Why" callout is dynamic — explains protein vs carb emphasis based on session type and readiness (green/yellow/red)
- Eaten values remain mock until 4.2 (real food logging) lands

---

## Phase 5 — Coach Chat ✅ (implemented — Apple Foundation Models)

All AI in HealthFit runs on-device via Apple's Foundation Models framework. No data leaves the device.

### 5.1 Chat UI ✅
- `CoachView` replaces `CoachPlaceholder` with a full streaming message thread
- User and assistant bubbles via `ChatBubble` component
- Input bar with multi-line `TextField`, send button, and streaming indicator

### 5.2 Foundation Models Integration ✅
- `FoundationModelService.streamCoachReply(to:context:)` streams responses via `LanguageModelSession`
- Persistent `coachSession` maintains conversation history within the session
- Context (readiness score, plan week) injected into each prompt automatically
- Graceful unavailable state shown on non-Apple Intelligence devices

### 5.3 Proactive Coach Nudges
- Surface coach suggestions on the Today tab (e.g., "You're under on protein — add a shake before your lift")
- Generate a brief end-of-week summary when the plan week closes
- `FoundationModelService.enhanceReadinessReasoning(_:userName:state:)` can personalise the morning briefing text

---

## Phase 6 — Notifications & Engagement

### 6.1 Morning Briefing Notification
- Send a push notification each morning once HealthKit data is processed (typically 06:00–07:00)
- Deep link directly into the Today tab readiness card

### 6.2 Workout Reminders
- Local notification 30 minutes before a scheduled session (based on a preferred workout time set in Settings)
- Cancel if the session is already logged as complete

### 6.3 Nutrition Nudges
- Mid-day notification if the user is significantly behind on protein or calories
- Suppress if the user has already hit targets

---

## Phase 7 — Settings & Account Management

### 7.1 Settings Screen
- Edit name, age, weight, goal weight
- Toggle units (lbs ↔ kg, miles ↔ km)
- Set preferred workout time (used by reminders)
- Notification preferences
- Manage HealthKit permissions (deep link to iOS Settings)

### 7.2 Account Actions
- Sign out
- Delete account (required for App Store — must delete all user data)
- Export my data

---

## Phase 8 — App Store Readiness

### 8.1 Assets & Branding
- App icon (1024×1024 + all required sizes) — `healthfit_icon.svg` exists in the project root but has not been configured as the app icon asset
- Launch screen
- App Store screenshots (6.7", 6.1", iPad if applicable)

### 8.2 Legal & Compliance
- Privacy policy (required — app collects health data)
- Terms of service
- HealthKit entitlement justification for App Store review

### 8.3 Quality
- Unit tests for `ReadinessService`, plan generation parsing, and macro calculations (current test files in `HealthfitTests/` are empty stubs)
- UI tests for the critical path: onboarding → Today tab readiness display
- Crash reporting (Sentry or Firebase Crashlytics)
- Analytics for key events: onboarding completed, plan generated, food logged, workout started

---

## Dependency Map

```
Phase 1 (Foundation)
  └── Phase 2 (HealthKit)     → unlocks real readiness
  └── Phase 3 (Plan Gen)      → unlocks real workouts
       └── Phase 5 (Coach)    → needs plan context
  └── Phase 4 (Nutrition)     → unlocks real food log
  └── Phase 6 (Notifications) → needs HealthKit + plan
  └── Phase 7 (Settings)      → needs auth + profile

Phase 8 (App Store) → depends on all phases complete
```

---

## Known Prototype Shortcuts to Resolve

| Location | Shortcut | Production fix |
|---|---|---|
| `ConnectWatchView.connect()` | Fake 0.9s delay, sets `watchConnected = true` | Real `HKHealthStore.requestAuthorization` |
| `AppState.readinessState` | Manual toggle in toolbar | Replace with `ReadinessService` output |
| `TodayView` header | Hardcoded "Wednesday · April 29" | `Date()` formatted to current day |
| `PlanGeneratedView` hero | Hardcoded "Apr 27 – May 3" | Computed from current week |
| `PlanInputView` | `description` seeded from `MockData.demoUser` | Load from persisted `UserProfile` |
| `PlanInputView` parsedCard | `MockData.parsedInput` | Real NLP parser output |
| `AppState.regeneratePlan()` | Reloads same `MockData.hybridWeek` | Call plan generation service |
| `FoodView` | `MockData.dayNutrition` directly referenced | Load from persistent `DayNutrition` store |
| `PhotoLogSheet` suggestions | `MockData.foodPickerSuggestions` | Food recognition API response |
| `WelcomeView` sign-in button | No-op stub | Route to sign-in screen |
| All action buttons (`Start workout`, `Lock in plan`, `Swap a day`, etc.) | Empty closures `{}` | Implement handlers |

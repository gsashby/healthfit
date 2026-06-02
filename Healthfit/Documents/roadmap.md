# HealthFit — Product Roadmap

## Current State (as of Phase IV)

HealthFit is a production-quality iOS app with a full five-tab layout (Today, Plan, Eat, Coach, Watch), a five-step onboarding flow, and live integrations across HealthKit, Apple Foundation Models, USDA FoodData Central, and the Vision framework. Phases 1–5 are complete. Phase 6 (notifications) is next.

---

## Phase 1 — Foundation ✅

### 1.1 Authentication ✅
- Apple Sign In and email/password sign-up implemented
- "I already have an account" routes to `SignInView` sheet
- Secure Keychain storage for session tokens
- Session restored on launch — onboarding skipped for returning users

### 1.2 User Profile Persistence ✅
- Onboarding captures name, age, sex, weight, goal weight
- `UserProfile` persisted via SwiftData (`PersistedProfile`)
- Settings screen allows post-onboarding edits

### 1.3 Local Persistence Layer ✅
- SwiftData (`PersistedProfile` model) for user profile, goals, training preferences, dietary profile
- UserDefaults (date-keyed) for today's food log — auto-clears at midnight
- UserDefaults for plan description, onboarding flags

### 1.4 Real Date & Time ✅
- All date strings computed from `Date.now`
- `PlanDay.isToday` and `dayNumber` reflect the real calendar
- Plan week range computed from Monday of current week

---

## Phase 2 — HealthKit Integration ✅

### 2.1 HealthKit Authorization ✅
- `ConnectWatchView` calls `HKHealthStore.requestAuthorization` for HRV, sleep, RHR, active energy, workouts
- `watchConnected` persisted; authorization step skipped on subsequent launches

### 2.2 Readiness Score Calculation ✅
- `ReadinessService` reads last night's HRV (SDNN), sleep score, and resting HR
- Score (0–100) mapped to `.green / .yellow / .red` `ReadinessState`
- Demo toggle kept in toolbar for testing on the simulator

### 2.3 Background HealthKit Delivery ✅
- Background delivery registered for HRV, sleep, and RHR types
- Local notification scheduled when overnight data is ready

### 2.4 Workout Sync ✅
- Completed workouts written to HealthKit (`HKWorkout`) after session ends
- Calories and duration computed from session kind (MET values) and elapsed time

---

## Phase 3 — AI Plan Generation ✅

### 3.1 NLP Input Parsing ✅
- `FoundationModelService.parseInput(_:)` extracts goals, modalities, session length, and constraints via `@Generable` structured output
- "What I heard" card updates live with parsed result

### 3.2 Plan Generation ✅
- `FoundationModelService.generateWeekPlan(...)` produces a `GeneratedPlan` on-device — no backend, fully private
- Prompt includes training type, strength split, readiness state, and user description
- Split-specific naming instructions prevent the model generating upper/lower sessions when full-body is selected
- Falls back to `MockData.plan(trainingType:strengthSplit:)` when Apple Intelligence is unavailable

### 3.3 Readiness-Driven Daily Adjustment ✅
- Session load, chips, and macros all adjust based on `.green / .yellow / .red` readiness
- "As planned" / "Adjusted" tag shown on workout card
- Red readiness substitutes a recovery walk regardless of plan

### 3.4 Plan Actions ✅
- Lock in plan, Swap a day, Start workout, Accept adjusted plan, Move to tomorrow, Keep original, Full rest day — all wired
- `WorkoutSessionView` tracks per-set weight/reps, warmup sets, RIR ratings, add/remove sets, skip exercise
- Post-workout summary shows duration, calories, sets logged, total volume

### 3.5 Multi-Week Progression ✅
- Week index tracked across a 12-week block with Base → Build → Peak → Taper phases
- Plan advances at week rollover; `needsNewWeekPlan` triggers the summary card and generation prompt
- Progress bar shown in Plan tab header

---

## Phase 4 — Nutrition ✅

### 4.1 Food Database Integration ✅
- `FoodDatabaseService` queries USDA FoodData Central (`DEMO_KEY`; register at fdc.nal.usda.gov for production limits)
- Nutrient IDs 1008/1003/1005/1004 parsed; per-100g values scaled to serving size
- 0.5 s debounce; graceful network error state
- `FoodSearchView` — live search bar, lazy result rows, serving picker (0.5× increments), live macro summary

### 4.2 Real Food Logging ✅
- `FoodEntry` and `Macros` are `Codable`; log persisted to UserDefaults keyed by `yyyy-MM-dd`
- `logFood`, `removeFoodEntry`, `updateFoodEntry` on `AppState`
- Macro ring and bars compute from actual log entries
- Empty state, swipe-to-delete, and swipe-to-edit on all meal rows
- Manual entry form (`FoodEntryForm`) shared between add and edit flows

### 4.3 Photo-Based Food Recognition ✅
- `CameraPickerView` wraps `UIImagePickerController`; falls back to photo library on simulator
- `classifyFoodInImage(_:)` runs `VNClassifyImageRequest` on-device; cleans Vision identifiers and skips generic labels
- "Scan with camera" → fullScreenCover → Vision classify → `FoodSearchView(initialQuery:)` pre-populated

### 4.4 Dietary Profile Capture ✅
- Onboarding step 3 of 5: 8 allergens (multi-select, red) + 8 preferences (multi-select, green); skippable
- Settings "Dietary profile" section for post-onboarding edits
- Allergen matching in `MealRow` and `PhotoLogSheet` — red badge, ⚠ banner, tinted card background
- Persisted to SwiftData via `PersistedProfile`

### 4.5 Macro Targets from Plan Context ✅
- `FoodView` derives kcal/macro targets from `appState.adjustedTodayWorkout(readiness:)`
- Dynamic "Why" callout: protein-high on lift days, carb-high on run days, reduced on recovery days
- Targets update in sync with readiness state (green/yellow/red)

---

## Phase 5 — Coach Chat ✅

### 5.1 Chat UI ✅
- Streaming message thread with user/assistant bubbles
- Multi-line input bar with send button and streaming indicator

### 5.2 Foundation Models Integration ✅
- `streamCoachReply(to:context:)` streams via persistent `LanguageModelSession`
- Readiness score and plan week injected as context
- Graceful unavailable state on non-Apple Intelligence devices

### 5.3 Proactive Coach Nudges ✅
- **Personalized morning briefing** — `enhanceReadinessReasoning` rewrites the rule-based reasoning with the user's first name and a warmer tone; static text shows immediately, AI version replaces it in-place
- **Nutrition nudge card** — below the nutrition section; rule-based fallback (protein gap, calorie gap, on-track); AI-enhanced via `generateCoachNudge` when available
- **End-of-week summary card** — appears when `needsNewWeekPlan`; AI or rule-based summary + "Plan Week N →" button
- FM calls run sequentially (Foundation Models cannot handle concurrent sessions)

---

## Phase 6 — Notifications & Engagement ✅

### 6.1 Morning Briefing Notification ✅
- `ReadinessService.scheduleMorningNotification(data:hour:enabled:)` schedules a daily 7 AM `UNCalendarNotificationTrigger` carrying the readiness score, state label, and reasoning; called from `TodayView.task` after each readiness fetch
- `AppNotificationDelegate` (in `HealthFitApp`) shows banners even when the app is foregrounded; notification tap deep-links to the Today tab via `NotificationCenter.default.post(name: .healthfitSwitchTab)`
- `MainTabView` binds `TabView(selection:)` to `appState.selectedTab`; `HealthFitApp` observes `healthfitSwitchTab` and updates `selectedTab`

### 6.2 Workout Reminders ✅
- `ReadinessService.scheduleWorkoutReminder(hour:minute:sessionName:enabled:)` fires 30 min before the user's preferred workout time (configurable in Settings)
- Session name from today's plan is embedded in the notification body
- `AppState.acceptTodaySession()` removes the pending request immediately when the workout is logged
- Reminder is skipped (`enabled: false`) when session is already accepted

### 6.3 Nutrition Nudges ✅
- `ReadinessService.scheduleNutritionNudge(sessionKind:enabled:)` fires at 12:00 noon with session-specific copy (lift day → protein focus; run day → carb focus; rest → general)
- `AppState.logFood(_:)` calls `cancelNutritionNudgeIfOnTrack()` after every food log entry; nudge is cancelled when kcal or protein is ≥ 80 % of the day's target
- All three notification types toggle-controlled in Settings "Notifications" section with a `DatePicker` for workout time

---

## Phase 7 — Settings & Account Management

### 7.1 Settings Screen ✅
- Profile editing (name, age, sex, weight, goal weight) ✅
- Dietary profile editing ✅
- Preferred workout time + notification preferences ✅
- **Units toggle** ✅ — "Use metric units" toggle in new Preferences section; weights displayed/entered as kg, volumes as kg; profile weight fields convert on load and save; `±2.5 kg` steps in workout logger when metric
- **HealthKit permissions deep-link** ✅ — "Manage Health permissions" opens iOS Settings via `UIApplication.openSettingsURLString`

### 7.2 Account Actions ✅
- Sign out ✅
- Delete account ✅
- **Export my data** ✅ — "Export my data" button writes a pretty-printed JSON file (`healthfit-export-yyyy-MM-dd.json`) to a temp directory and presents the system share sheet; includes user profile, training preferences, dietary profile, today's food log, and full exercise history

---

## Phase 8 — App Store Readiness

### 8.1 Assets & Branding
- App icon configured in asset catalog (`healthfit_icon.svg` → PNG sizes) ✅
- **Launch screen** ✅ — `LaunchImage.imageset` (3-scale kettlebell icon @1x/2x/3x) + `LaunchBackground.colorset` (pure black); wired via `INFOPLIST_KEY_UILaunchScreen_*` build settings in both Debug and Release configs
- App Store screenshots — pending

### 8.2 Legal & Compliance
- **Privacy policy** ✅ — `Documents/privacy-policy.md`; covers HealthKit data use, on-device storage, USDA/Open Food Facts API calls (search terms only), on-device AI, no backend, export + deletion rights, GDPR/CCPA, health data disclaimer. Requires a hosted URL before App Store submission — replace contact placeholder and host on GitHub Pages or similar.
- **HealthKit entitlement justification** ✅ — `Documents/healthkit-justification.md`; per-type justification text ready to paste into App Store Connect, covering all 5 read types (HRV, sleep, RHR, active energy, workouts) and 3 write types (workouts, active energy, distance), plus a data minimisation statement and background delivery rationale.
- Terms of service — pending (recommended but not required for a free app)

### 8.3 Quality ✅

**Unit tests** (`HealthfitTests/HealthfitTests.swift`) — 22 tests across 7 suites using Swift Testing:
- `ExerciseRecord: Epley 1RM` — formula, best-set selection, zero-guard
- `AppState: weight suggestions` — 1RM → training %, rounding, case-insensitive lookup, recency, minimum weight
- `AppState: exercise history` — record storage, zero-weight filtering, 20-session cap
- `ReadinessService: score calculation` — perfect/poor/mixed metrics, nil fallbacks, state thresholds
- `AppState: macro targets` — green/yellow/red kcal and macro values
- `AppState: unit conversion` — lbs↔kg roundtrip, suffix, step size
- `FoodEntry: Codable` — encode/decode roundtrip, array persistence
- `AppState: food log` — log, remove, update by id

**UI smoke tests** (`HealthfitUITests/HealthfitUITests.swift`) — 8 XCTest methods:
- App launches without crashing
- Onboarding or tab bar appears within 5 s
- All 4 tabs reachable and selectable
- Today tab shows readiness score (live or DEMO)
- Eat tab shows macro card
- Plan tab has segmented control

**Crash reporting** (`CrashReporter.swift`) — no-op scaffold with wiring instructions for Sentry and Firebase Crashlytics; `CrashReporter.configure()` called in `HealthFitApp.init()`

**Analytics** (`Analytics.swift`) — no-op event bus (prints in DEBUG) with wiring instructions for TelemetryDeck and PostHog; 6 events fired: `onboarding_completed`, `plan_generated`, `workout_started`, `workout_completed`, `food_logged`, `coach_message_sent`

---

## Phase 9 — Today Screen Redesign & Workout UX Polish ✅

### 9.1 Today Screen Redesign ✅

New layout order (top → bottom): Header → Readiness → Coach → Today's Fuel → Session widget (or post-workout summary).

- **Readiness card** — HRV, Sleep, and Resting HR vitals embedded inside the card below the score, separated by a hairline divider and vertical separators between columns; color-coded trend text (green/red/muted)
- **Coach insight card** ✅ — moved from bottom to just below Readiness; now collapsible (purple "C" badge + chevron); vitals-aware rule-based fallback (reads HRV trend, sleep, RHR) plus `generateCoachInsight` FM prompt; text toggles with spring animation
- **Today's Fuel card** ✅ — collapsible; calorie tracker (consumed / target, blue progress bar, "N kcal left") always visible in header; Carbs / Protein / Fat macros collapse beneath a hairline separator
- **Session widget** ✅ — single collapsible card merging Today's Session, Why this session, and action buttons; collapsed state shows session name + meta + "N exercises · tap to expand" hint; expanded shows flow-wrapped exercise chips, inline reasoning with blue "i" badge, and action buttons
- **Goal chip and standalone sections removed** — goal chip, watch data banner, week summary card, and standalone workout/reasoning/actions cards replaced by the session widget

### 9.2 Workout Flow ✅

- **Workout preview screen** (`WorkoutPreviewView`) ✅ — "View Workout" opens a dedicated preview sheet showing session name/duration, exercise chip list, and reasoning callout; "Start Workout" button pinned at bottom dismisses preview and opens `WorkoutSessionView` (uses `onDismiss` + `shouldStartWorkout` flag to chain sheets reliably)
- **Tap-to-edit logged sets** ✅ — tapping a done set row (green checkmark) in an active exercise switches it to inline edit mode (weight + reps fields); checkmark becomes an X; tapping X or keyboard Done exits edit; keyboard Done button clears edit state
- **Edit completed exercises** ✅ — tapping a done exercise row (pencil icon on right) expands it to the full set table in edit mode; cue reads "Editing completed exercise."; all logged set rows editable via tap-to-edit; "Done editing" button collapses back; tapping another done row swaps which one is open; skipped exercises are not expandable

### 9.3 Post-Workout Summary ✅

- **Post-workout summary card** ✅ — `CompletedWorkoutSummary` and `CompletedExerciseSummary` models in `Models.swift`; `AppState.completedWorkoutSummary` stores the summary after session ends (reset on day rollover / plan moves); HR samples collected every 5 s during workout, averaged for avg BPM; card replaces the session widget when workout is accepted
- **Workout card + reasoning card hidden post-workout** ✅ — readiness, coach, and fuel cards remain; session widget replaced by summary
- **Summary card collapsible** ✅ — header (checkmark, session name, "Completed") and stats row (duration, avg BPM, calories) always visible; "Session highlights" (per-exercise sets, weight, est. 1RM) toggle via chevron

### 9.4 Watch Bug Fixes ✅

- Replaced deprecated `NavigationLink(isActive:)` with `navigationDestination(isPresented:)` in `ContentView.swift` (watchOS 9+ requirement)
- Fixed always-succeeds conditional cast `dict as? [String: Any]` in `WatchConnectivityReceiver.applySync` → `let syncDict = (dict["workoutSync"] as? [String: Any]) ?? dict`
- Marked `WatchWorkoutController.parse(_:)` as `nonisolated` to resolve Swift 6 main-actor isolation warning

---

## Dependency Map

```
Phase 1 (Foundation)
  └── Phase 2 (HealthKit)       → unlocks real readiness
  └── Phase 3 (Plan Gen)        → unlocks real workouts
       └── Phase 5 (Coach)      → needs plan context ✅
  └── Phase 4 (Nutrition)       → unlocks real food log
  └── Phase 6 (Notifications)   → needs HealthKit + plan
  └── Phase 7 (Settings)        → needs auth + profile (partial ✅)

Phase 8 (App Store) → depends on all phases complete
```

---

## Resolved Prototype Shortcuts

| Location | Was | Now |
|---|---|---|
| `ConnectWatchView` | Fake 0.9 s delay | Real `HKHealthStore.requestAuthorization` |
| Readiness state | Manual toolbar toggle | `ReadinessService` live output |
| Date strings | Hardcoded | `Date()` computed |
| Plan week range | Hardcoded | Computed from current Monday |
| `PlanInputView` description | `MockData.demoUser` | Persisted `lastPlanDescription` |
| Plan generation | Static `MockData.hybridWeek` | FM + split-appropriate mock fallback |
| Food data | `MockData.dayNutrition` | Real log + USDA + camera + barcode |
| Photo log suggestions | `MockData.foodPickerSuggestions` | USDA search + Vision classification |
| Sign-in button | No-op | `SignInView` sheet |
| Plan/workout actions | Empty closures | Fully wired |

## Outstanding Prototype Items

| Location | Shortcut | Production fix |
|---|---|---|
| `MockData.foodPickerSuggestions` | Still used in `PhotoLogSheet` scanning phase | Replace with Vision → USDA results inline |
| `PlanInputView` parsed card | Falls back to `MockData.parsedInput` on FM failure | Cache last real parse result |
| Units | lbs/miles hardcoded throughout | `UserDefaults`-backed unit preference |
| Preferred workout time | Not captured | Add to Settings; drive notification scheduling |

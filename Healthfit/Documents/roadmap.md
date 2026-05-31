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

## Phase 6 — Notifications & Engagement

### 6.1 Morning Briefing Notification
- Push notification when HealthKit overnight data is processed (~06:00–07:00)
- Deep link to Today tab readiness card

### 6.2 Workout Reminders
- Local notification 30 min before scheduled session (based on preferred workout time in Settings)
- Auto-cancel when session is logged

### 6.3 Nutrition Nudges
- Mid-day notification when significantly behind on protein or calories
- Suppressed when targets are met

---

## Phase 7 — Settings & Account Management

### 7.1 Settings Screen (partial ✅)
- Profile editing (name, age, sex, weight, goal weight) ✅
- Dietary profile editing ✅
- Units toggle (lbs ↔ kg, miles ↔ km) — **pending**
- Preferred workout time — **pending**
- Notification preferences — **pending**
- HealthKit permissions deep-link — **pending**

### 7.2 Account Actions (partial ✅)
- Sign out ✅
- Delete account ✅
- Export my data — **pending**

---

## Phase 8 — App Store Readiness

### 8.1 Assets & Branding
- App icon configured in asset catalog (`healthfit_icon.svg` → PNG sizes) ✅
- Launch screen — pending
- App Store screenshots — pending

### 8.2 Legal & Compliance
- Privacy policy — pending
- Terms of service — pending
- HealthKit entitlement justification — pending

### 8.3 Quality
- Unit tests (`HealthfitTests/` stubs exist) — pending
- UI tests for critical path — pending
- Crash reporting — pending
- Analytics — pending

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

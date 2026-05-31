# HealthFit

An adaptive iOS fitness and nutrition coach powered by Apple Health, on-device AI, and a full weekly training plan system. All intelligence runs on-device via Apple Foundation Models — no data leaves the device.

## What it does

- **Today tab** — morning readiness briefing from live HealthKit biometrics (HRV, sleep, resting HR); workout card adjusted for green/yellow/red readiness; AI-personalised reasoning and nutrition nudge; end-of-week summary when the training block rolls over
- **Plan tab** — AI-generated 7-day training plans from free-text input; split-aware exercise chips (Full body / PPL / Upper-lower); per-set weight logging, RIR ratings, warmup sets; readiness-driven intensity adjustment; multi-week block progression
- **Eat tab** — food search via USDA database, barcode scanning (Open Food Facts), and camera-based Vision classification; real macro tracking vs plan-derived targets; allergen warnings from dietary profile
- **Coach tab** — streaming AI chat with persistent conversation history and plan/readiness context injection
- **Watch companion** — today's workout and readiness score pushed via WatchConnectivity

## Requirements

- Xcode 16+
- iOS 18.1+ deployment target
- iPhone 15 Pro or later for Apple Intelligence features (all features degrade gracefully without it)

## Quick start

1. Clone the repo and open `Healthfit.xcodeproj` in Xcode
2. Select your development team under **Signing & Capabilities**
3. Build and run on a device or the iPhone 15 simulator
4. On first launch, complete the five-step onboarding (Welcome → Sign up → Profile → Dietary → Training goals → Connect Watch)

**Apple Intelligence** (plan generation, personalised briefing, coach nudges) requires an iPhone 15 Pro or later running iOS 18.1+. On other devices the app falls back to split-appropriate mock plans and rule-based text throughout.

**HealthKit** (live readiness scoring) requires an Apple Watch paired to the device. Without it the app shows a demo readiness score with a toggle in the Today toolbar.

**Camera / barcode** require a physical device for full functionality; the simulator falls back to the photo library for camera and shows a static scanner UI for barcodes.

## Documentation

| Document | Contents |
|---|---|
| [`Documents/roadmap.md`](Documents/roadmap.md) | Phase-by-phase feature status; what's done, what's next |
| [`Documents/architecture.md`](Documents/architecture.md) | File structure, data flow, AppState API, persistence, AI architecture |
| [`Documents/api-reference.md`](Documents/api-reference.md) | External APIs, permissions, entitlements, rate limits |

## Tech stack

| Layer | Technology |
|---|---|
| UI | SwiftUI |
| State | `ObservableObject` + `@EnvironmentObject` |
| Persistence | SwiftData (`PersistedProfile`) + UserDefaults (food log, flags) |
| On-device AI | Apple Foundation Models (`FoundationModels` framework) |
| Health data | HealthKit + `HKHealthStore` |
| Image recognition | Vision (`VNClassifyImageRequest`) |
| Barcode scanning | VisionKit (`DataScannerViewController`) |
| Watch | WatchConnectivity + watchOS companion target |
| Food database | USDA FoodData Central API + Open Food Facts API |
| Camera | `UIImagePickerController` / `UIViewControllerRepresentable` |

## Project layout

```
Healthfit/
├── AppState.swift              Central state + AuthService + WatchConnectivityService
├── FoundationModelService.swift All on-device AI calls
├── ReadinessService.swift      HealthKit → readiness score
├── Models.swift                All data models + SwiftData @Model
├── MockData.swift              Split-aware fallback plans
├── Components.swift            Reusable UI components
├── Theme.swift                 Design system
├── MainTabView.swift           Tab container + CoachView + SettingsView
├── Onboarding/                 5-step onboarding flow
├── Today/                      Morning briefing + workout session
├── Plan/                       Plan input, generated view, day cards
├── Food/                       Food log, USDA search, camera, barcode
├── HealthfitWatch/             watchOS companion app
└── Documents/                  Project documentation
```

## Key design decisions

**Single AppState** — all mutable state lives in one `@MainActor ObservableObject` injected at the root. Views read from it; no separate ViewModels. This keeps the data flow predictable and makes the readiness → workout → nutrition chain easy to trace.

**Split-aware exercise chips** — `liftChips(sessionName:)` checks `strengthSplit` first, so exercises always match the user's chosen split regardless of what the AI names the sessions. The AI prompt also receives split-specific naming instructions to keep the plan view consistent.

**Sequential FM calls** — Foundation Models cannot handle concurrent `LanguageModelSession` instances. The three nudge calls in `TodayView.task` (reasoning enhancement, nutrition nudge, week summary) run sequentially to prevent deadlock.

**Date-keyed food log** — `todayFoodLog` is stored in UserDefaults under `foodLog_yyyy-MM-dd`. The key changes at midnight, so yesterday's log is never loaded. No explicit cleanup is needed.

**No backend** — every feature works entirely on-device. USDA and Open Food Facts are the only network calls.

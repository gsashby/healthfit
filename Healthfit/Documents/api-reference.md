# HealthFit — API & Permissions Reference

## External APIs

### USDA FoodData Central

**Purpose:** Food search by name — returns nutritional data (kcal, protein, carbs, fat) per 100g and per branded serving size.

**Endpoint:** `https://api.nal.usda.gov/fdc/v1/foods/search`

**Auth:** API key in query string (`api_key=DEMO_KEY`)

**Current key:** `DEMO_KEY` — rate limited to 30 requests/hour, 50/day.  
**Production:** Register a free key at [fdc.nal.usda.gov/api-key-signup.html](https://fdc.nal.usda.gov/api-key-signup.html) for 1,000 requests/hour.

**Key nutrient IDs parsed:**

| ID | Nutrient |
|---|---|
| 1008 | Energy (kcal) |
| 1003 | Protein (g) |
| 1005 | Carbohydrate by difference (g) |
| 1004 | Total lipid / fat (g) |

**Key used in:** `Food/FoodDatabaseService.swift` → `FoodDatabaseService`

**Data types used in:** `FoodSearchResult` — per-100g values scaled to `servingSizeG` (defaults to 100g when absent).

**Debounce:** 0.5 s — in-flight task cancelled on each new keystroke.

---

### Open Food Facts

**Purpose:** Barcode lookup — returns product name, brand, and nutritional data by EAN/UPC barcode.

**Endpoint:** `https://world.openfoodfacts.org/api/v2/product/{barcode}.json`

**Auth:** None required (open database).

**Key used in:** `Food/OpenFoodFactsService.swift` → `OpenFoodFactsService`

**Fields parsed:** `product_name`, `brands`, `nutriments` (energy-kcal_100g, proteins_100g, carbohydrates_100g, fat_100g), `serving_size`.

---

## Apple Frameworks

### HealthKit

**Purpose:** Read biometric data for readiness scoring; write completed workouts.

**Key used in:** `ReadinessService.swift`, `ConnectWatchView.swift`, `Today/TodayView.swift` (workout save)

**Requested permissions:**

| Data type | Permission | Purpose |
|---|---|---|
| HRV (SDNN) | Read | Readiness score |
| Sleep analysis | Read | Readiness score |
| Resting heart rate | Read | Readiness score |
| Active energy burned | Read | Readiness context |
| Workouts | Read + Write | Save completed sessions |

**Usage description strings (Info.plist):**
- `NSHealthShareUsageDescription` — "HealthFit reads your HRV, sleep, and heart rate to calculate daily readiness and adapt your training plan."
- `NSHealthUpdateUsageDescription` — "HealthFit saves your completed workouts to Apple Health."

**Background delivery:** Registered for HRV, sleep, and RHR so readiness recalculates overnight.

---

### Apple Foundation Models

**Purpose:** On-device AI for plan generation, coach chat, reasoning personalisation, and nudges.

**Framework:** `FoundationModels` (iOS 18.1+, iPhone 15 Pro or later)

**No API key required.** All data stays on device.

**Availability check:** `SystemLanguageModel.default.availability` — graceful fallback to rule-based behaviour when unavailable.

**Key used in:** `FoundationModelService.swift`

**Structured output types:** `@Generable GeneratedPlan`, `@Generable GeneratedDay`, `@Generable GeneratedSession`, `@Generable ParsedUserInput`

**Concurrency constraint:** Foundation Models cannot handle concurrent `LanguageModelSession` instances. All calls in `TodayView.task` run sequentially.

---

### Vision

**Purpose:** On-device food classification from camera images.

**Framework:** `Vision` (imported with `@preconcurrency` to suppress Sendable warnings)

**No API key required.** Runs entirely on-device.

**Request used:** `VNClassifyImageRequest` — general image classifier; food-related labels extracted by filtering generic categories (`"food"`, `"produce"`, `"meal"`, etc.).

**Label cleaning:** Underscores replaced with spaces; parenthetical qualifiers stripped (e.g., `"orange_(fruit)"` → `"orange"`).

**Key used in:** `Food/CameraFoodRecognizer.swift` → `classifyFoodInImage(_:)`

---

### DataScanner (VisionKit)

**Purpose:** Live barcode scanning overlay.

**Framework:** `VisionKit.DataScannerViewController`

**Recognised types:** `.barcode` (EAN-8, EAN-13, UPC-A, UPC-E, Code 128, QR)

**Key used in:** `Food/BarcodeScannerView.swift`

---

### WatchConnectivity

**Purpose:** Push today's workout payload to the Apple Watch companion.

**Framework:** `WatchConnectivity`

**Transport:** `WCSession.updateApplicationContext` (background delivery; latest value wins).

**Payload type:** `WatchWorkoutPayload` (Codable struct → JSON → `[String: Any]`)

**Key used in:** `AppState.swift` → `WatchConnectivityService`

---

## Required Permissions (Info.plist keys)

All permissions are declared via `INFOPLIST_KEY_*` in `project.pbxproj` (auto-generated Info.plist).

| Key | Value |
|---|---|
| `NSHealthShareUsageDescription` | "HealthFit reads your HRV, sleep, and heart rate to calculate daily readiness and adapt your training plan." |
| `NSHealthUpdateUsageDescription` | "HealthFit saves your completed workouts to Apple Health." |
| `NSCameraUsageDescription` | "HealthFit uses the camera to identify food items for your nutrition log." |

**Note:** `NSPhotoLibraryUsageDescription` is NOT required because `UIImagePickerController` fallback (simulator only) reads from the library via the system photo picker, which does not require a usage description in iOS 14+.

---

## Entitlements

File: `Healthfit/Healthfit.entitlements`

| Entitlement | Value |
|---|---|
| `com.apple.developer.healthkit` | `true` |
| `com.apple.developer.healthkit.background-delivery` | `true` |

---

## No-Key APIs Summary

| Service | Requires key? | Rate limits |
|---|---|---|
| USDA FoodData Central (DEMO_KEY) | Yes (free) | 30 req/hr, 50/day |
| USDA FoodData Central (registered) | Yes (free) | 1,000 req/hr |
| Open Food Facts | No | None (open) |
| Apple Foundation Models | No (on-device) | Hardware limited |
| Vision framework | No (on-device) | None |
| HealthKit | No (user grants) | None |
| WatchConnectivity | No | System managed |

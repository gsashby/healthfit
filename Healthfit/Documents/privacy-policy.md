# HealthFit Privacy Policy

**Last updated:** June 1, 2026

HealthFit ("we", "our", or "the app") is committed to protecting your privacy. This policy explains what data HealthFit collects, how it is used, and your rights over that data.

---

## 1. Summary

- **All your data stays on your device.** HealthFit has no backend servers. Your health data, food log, workout history, and personal profile are never transmitted to us or any third party.
- **HealthKit data is never shared.** HealthFit reads from Apple Health with your permission and writes completed workouts back. This data never leaves your device.
- **Food search sends only search terms.** When you search for food, a query (e.g. "chicken breast") is sent to the USDA database. No personal information is included.
- **On-device AI.** All AI features (plan generation, coach chat, readiness personalisation) run entirely on your device using Apple Foundation Models. No prompts or responses are transmitted.
- **You can delete everything.** Settings → Delete account removes all data stored by HealthFit.

---

## 2. Data We Store On Your Device

HealthFit stores the following data locally using Apple's SwiftData and UserDefaults frameworks. This data never leaves your device unless you choose to export it.

| Data | Purpose | Storage |
|---|---|---|
| Name, age, sex, weight, goal weight | Personalise workout plans and macro targets | SwiftData |
| Training preferences (type, split, days/week) | Generate appropriate training plans | SwiftData |
| Dietary profile (allergies, preferences) | Flag allergens in food suggestions | SwiftData |
| Food log (meal entries, macros, calories) | Track daily nutrition against plan targets | UserDefaults (resets daily) |
| Exercise history (weights, reps, estimated 1RM) | Suggest starting weights for future sessions | UserDefaults |
| Notification preferences and workout time | Schedule local notifications | UserDefaults |
| Unit preference (lbs/kg) | Display weights and distances consistently | UserDefaults |
| Current training plan | Power the Plan and Today tabs | In-memory + SwiftData |

---

## 3. Apple HealthKit Data

HealthFit requests permission to read the following Apple Health data types:

| Data type | Why it is read |
|---|---|
| Heart Rate Variability (HRV, SDNN) | Calculate your daily readiness score |
| Sleep analysis (duration + stages) | Contribute to your daily readiness score |
| Resting heart rate | Contribute to your daily readiness score |
| Active energy burned | Context for daily activity level |
| Workouts (historical) | Inform training load and plan generation |

HealthFit writes the following data to Apple Health:

| Data type | Why it is written |
|---|---|
| Workouts (completed sessions) | So sessions appear in Activity rings and the Health app |
| Active energy burned | Calorie expenditure from completed workout sessions |
| Walking/running distance | Estimated distance for run and walk sessions |

**HealthKit data is never transmitted, stored externally, shared with third parties, or used for advertising.** All processing happens on-device.

---

## 4. External API Calls

HealthFit makes network requests to two external services for food data. **No personal information is included in any of these requests.**

### USDA FoodData Central
- **What is sent:** Food name search terms (e.g. "banana", "chicken breast")
- **What is received:** Nutritional data (calories, macros, serving size)
- **Privacy policy:** https://www.nal.usda.gov/privacy-policy
- **No account required.** HealthFit uses a free public API key.

### Open Food Facts
- **What is sent:** Product barcode numbers (EAN/UPC)
- **What is received:** Product name and nutritional data
- **Privacy policy:** https://world.openfoodfacts.org/privacy
- **Open database** — no personal data is associated with barcode lookups.

---

## 5. On-Device AI (Apple Foundation Models)

Plan generation, coach chat, readiness personalisation, and nutrition nudges use Apple's on-device Foundation Models framework. All AI inference runs locally on your device.

- No prompts, responses, or context are transmitted to Apple or any third party.
- Foundation Models require iPhone 15 Pro or later with iOS 18.1+. The app functions fully without AI features on other devices.

---

## 6. Local Notifications

HealthFit schedules local notifications on your device for:
- Morning readiness briefing
- Workout reminders (30 min before your preferred workout time)
- Midday nutrition check

These notifications are generated and delivered entirely on your device. No notification content is transmitted externally.

---

## 7. Analytics and Crash Reporting

HealthFit currently does **not** use any third-party analytics or crash reporting service. The analytics and crash reporting code in the app is a no-op scaffold that prints to the debug console only. No data is transmitted.

If a third-party analytics or crash reporting service is added in a future version, this policy will be updated and users will be notified.

---

## 8. Data Sharing

HealthFit **does not** sell, rent, license, or share your personal data with any third party for any purpose, including advertising or marketing.

The only external communication HealthFit performs is:
- Food name search queries to USDA (no personal data)
- Barcode queries to Open Food Facts (no personal data)

---

## 9. Data Export and Deletion

**Export:** Settings → Export my data generates a JSON file containing your profile, training preferences, dietary profile, food log, and exercise history. You can share this file anywhere using the standard iOS share sheet.

**Deletion:** Settings → Delete account permanently removes all data stored by HealthFit on your device, including SwiftData records, UserDefaults keys, and pending notifications. This action cannot be undone.

Deleting the app from your device will also remove all locally stored data. HealthKit data written by HealthFit (workouts) remains in the Health app and must be deleted separately from within the Health app if desired.

---

## 10. Children's Privacy

HealthFit is not directed at children under 13. We do not knowingly collect personal information from children under 13. If you are a parent or guardian and believe your child has provided personal information through the app, please contact us.

---

## 11. Your Rights

Depending on your location, you may have the following rights under GDPR (EU/UK), CCPA (California), or other applicable law:

- **Right to access** — Export your data at any time via Settings → Export my data.
- **Right to deletion** — Delete all your data at any time via Settings → Delete account.
- **Right to portability** — Your exported data is machine-readable JSON.
- **Opt-out of sale** — HealthFit does not sell personal data. There is nothing to opt out of.

---

## 12. Health Data Disclaimer

HealthFit is a fitness and wellness application. It is **not a medical device** and is not intended to diagnose, treat, cure, or prevent any disease or health condition. The readiness scores, training adjustments, and nutrition targets provided by HealthFit are for informational and motivational purposes only.

Always consult a qualified healthcare provider before beginning a new exercise programme, particularly if you have a pre-existing medical condition.

---

## 13. Security

All data stored by HealthFit resides in iOS-protected storage (SwiftData and UserDefaults), protected by the device's hardware encryption and your passcode/Face ID. Authentication credentials (if used) are stored in the iOS Keychain.

---

## 14. Changes to This Policy

If we make material changes to this privacy policy, we will update the "Last updated" date at the top of this document and notify users within the app on next launch.

---

## 15. Contact

Questions about this privacy policy can be directed to:

**Email:** [your-email@example.com]  
**App Store listing:** [App Store link]

*Replace the placeholders above before submitting to the App Store.*

# HealthFit — HealthKit Usage Justification

*This document contains the text to paste into App Store Connect when submitting
for review. Each HealthKit type requires a separate justification explaining why
the data is accessed and how it benefits the user.*

---

## Read Types

### Heart Rate Variability (HRV, SDNN)

HealthFit reads Heart Rate Variability (SDNN) data recorded overnight by Apple
Watch to calculate the user's daily readiness score. HRV is a widely-used
biomarker for autonomic nervous system recovery; a higher HRV relative to the
user's personal 14-day baseline indicates stronger recovery and readiness to
train. The readiness score (0–100) directly determines whether today's planned
training session proceeds as scheduled, is reduced in intensity, or is replaced
with a recovery session. This is the core feature of the app and represents the
primary user benefit.

HRV data is processed entirely on-device, is never transmitted externally, and
is never shared with any third party.

---

### Sleep Analysis

HealthFit reads sleep analysis samples (total duration and sleep stage data)
from the previous night to contribute to the daily readiness score alongside
HRV and resting heart rate. Sleep quality and duration are established
predictors of next-day training performance; insufficient sleep (below 6 hours
or poor quality) reduces the readiness score and triggers a proportional
reduction in planned training intensity. Users see their sleep duration
displayed in the vitals row on the Today tab, giving them visibility into how
their sleep is influencing their training recommendation.

Sleep data is processed entirely on-device, is never transmitted externally, and
is never shared with any third party.

---

### Resting Heart Rate

HealthFit reads the user's resting heart rate (most recent measurement) and
compares it against their 14-day personal baseline to contribute to the daily
readiness score. An elevated resting heart rate — typically indicating
inadequate recovery, illness onset, or overtraining — reduces the readiness
score and triggers a downward adjustment to the planned session intensity. The
resting heart rate value and its trend are displayed in the vitals row on the
Today tab so users understand the physiological basis of their readiness
recommendation.

Resting heart rate data is processed entirely on-device, is never transmitted
externally, and is never shared with any third party.

---

### Active Energy Burned

HealthFit reads the user's recent active energy burned data to provide context
for daily activity level when calculating nutrition targets. On days with high
active energy expenditure, the app adjusts calorie and macro targets
accordingly. This data supplements the HealthKit workout data to give a more
complete picture of the user's energy needs.

Active energy data is processed entirely on-device, is never transmitted
externally, and is never shared with any third party.

---

### Workouts (Historical)

HealthFit reads the user's workout history from Apple Health to inform training
load analysis and plan generation. Understanding recent training frequency and
intensity helps the plan generation system avoid prescribing sessions that would
compound cumulative fatigue, and ensures progressive overload is applied at an
appropriate rate across the 12-week training block.

Workout history data is processed entirely on-device, is never transmitted
externally, and is never shared with any third party.

---

## Write Types

### Workouts (Completed Sessions)

HealthFit writes a completed workout session to Apple Health each time the user
finishes a tracked workout (strength training, running, yoga, or walking/
recovery). The written workout includes the activity type, start time, end time,
and estimated calorie expenditure (calculated from MET values appropriate to the
activity type and the user's body weight). Writing workouts to Apple Health
allows the session to appear in the Activity rings and the Health app's workout
history, giving users a unified view of all their physical activity in one place.

This is a standard, user-expected behaviour for any fitness application and
directly benefits the user by keeping their Apple Health record complete.

---

### Active Energy Burned (Written with Workouts)

When HealthFit writes a completed workout session to Apple Health, it also
writes an associated active energy burned sample representing the estimated
calorie expenditure for that session. This calorie figure is calculated from
published MET (Metabolic Equivalent of Task) values for each activity type
(strength training: MET 5, running: MET 9, yoga: MET 2.5, walking: MET 3)
multiplied by the user's body weight and elapsed session duration. Writing this
sample ensures the workout's calorie contribution is correctly reflected in the
user's daily Activity rings and Health app totals.

---

### Walking/Running Distance

For running and walking sessions, HealthFit writes an estimated distance sample
to Apple Health alongside the workout. The distance is derived from a
pace-appropriate speed estimate (2.7 m/s for runs, 1.3 m/s for walks) applied
to the session duration. While this is an approximation (GPS is not available),
writing a distance sample ensures the workout appears complete in the Health app
and contributes to the user's Move and Exercise ring data in a meaningful way.
Users are informed via the app that the distance is an estimate.

---

## Data Minimisation Statement

HealthFit requests only the HealthKit data types that are directly necessary to
deliver its core features:

- **Readiness scoring** requires HRV, sleep, and resting heart rate.
- **Activity context** requires active energy burned (read).
- **Training load analysis** requires workout history (read).
- **Health app integration** requires workout and active energy write access.

No HealthKit data types beyond those listed above are accessed. All HealthKit
data is processed on-device and is never transmitted to any external server,
shared with any third party, or used for advertising or analytics purposes.

---

## Background Delivery

HealthFit registers for HealthKit background delivery for HRV, sleep analysis,
and resting heart rate. This allows the app to recalculate the user's readiness
score and schedule the morning briefing notification after overnight data is
collected — typically between 5:00 AM and 7:00 AM — without requiring the user
to manually open the app each morning. The morning notification is the primary
way users receive their daily readiness briefing, and background delivery is
essential to its reliable delivery.

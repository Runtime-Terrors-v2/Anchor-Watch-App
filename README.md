# ANCHOR — Wearable Safety Companion for Seniors

> **"Early detection. Immediate alert. Peace of mind."**
ANCHOR is an open-source HarmonyOS app for Huawei Watch that silently monitors seniors for unsafe wandering and falls, then instantly notifies their caregiver. It's built for the real danger scenario: a patient quietly walks out the front door while their caregiver is occupied — ANCHOR catches it *early*, before they've wandered far.

---

## The Problem

Seniors with dementia or cognitive decline can wander out of the house without warning. By the time a caregiver notices, the person may be blocks away, disoriented, and in danger. Standard GPS trackers only tell you *where* someone is *after* the fact.

ANCHOR is different: it detects the *exit event itself* by combining motion and GPS, giving caregivers a head start.

---

## Features

### Geofencing (Motion + GPS)
Dual-signal detection for accuracy indoors and out:
- **Accelerometer** detects sustained walking (not just shifting in a seat)
- **GPS** confirms the person has left the home vicinity (30–50m radius)
- An alert only fires when **both agree** — minimising false alarms

**Drift States:**

| State | Meaning | Response |
|-------|---------|----------|
| `SAFE` | Within 30m of home, or no walking detected | No action |
| `DRIFTING` | Walking detected + 30–50m from home | 1 gentle haptic pulse on watch |
| `ALERT` | Walking detected + beyond 50m | 3 firm haptic pulses + push notification to caregiver's phone |

### Fall Detection
Two parallel detectors running simultaneously:
- **Threshold detector** — classic impact spike (>25 m/s²) followed by stillness
- **ML-inspired detector** — logistic regression classifier trained on the SisFall dataset, using 4 extracted features (impact peak, pre-impact energy, post-fall stillness, post-fall variance)

Falls trigger immediately regardless of geofence state — a fall *inside* the house is just as critical.

### Caregiver Alerts
- **Watch vibration** — haptic pattern on the patient's wrist (gentle, non-alarming)
- **Phone push notification** — "Your family member may have left home. Last known: Xm from home point."
- **Fall alert** — SMS/push to all emergency contacts with GPS coordinates and timestamp
- **Watch disconnect alert** — if the watch goes offline, contacts are notified

### Community Card
Stored on the watch for first-responders:
- Patient name, home address, preferred language
- Blood type, allergies, medical summary
- Two emergency contacts with tap-to-call

### Debug Panel (Emulator)
Long-press the ANCHOR title for 3 seconds to access a hidden debug panel to simulate walking, stillness, and fall events — essential for emulator testing.

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Huawei Watch                        │
│                                                      │
│  ┌────────────────┐     ┌────────────────────────┐   │
│  │MotionDetector  │────▶│                        │   │
│  │(accelerometer) │     │    GeofenceService     │   │
│  └────────────────┘     │  (state machine)       │──▶│ Haptics
│                          │                        │   │ Notifications
│  ┌────────────────┐     │  NOT_SET → SAFE →      │   │
│  │ GPS Location   │────▶│  DRIFTING → ALERT      │   │
│  │ (10s/60s poll) │     └────────────────────────┘   │
│  └────────────────┘                                   │
│                                                      │
│  ┌─────────────────┐   ┌──────────────────────────┐  │
│  │  FallDetector   │──▶│   NotificationService    │  │
│  │  (threshold/ML) │   │  (haptics + push)        │  │
│  └─────────────────┘   └──────────────────────────┘  │
└─────────────────────────────┬───────────────────────┘
                               │ WearEngine P2P / Push Kit
                               ▼
┌─────────────────────────────────────────────────────┐
│                  Caregiver's Phone                   │
│                                                      │
│  HomePage  ──  AlertHistory  ──  Contacts            │
│                                                      │
│  WatchMonitorService ──▶ SmsService ──▶ Cloud        │
│                                      (AGConnect)     │
└─────────────────────────────────────────────────────┘
```

### Module Breakdown

| Module | Target Device | Key Files |
|--------|--------------|-----------|
| `entry/` | Huawei Watch | `GeofenceService.ets`, `MLFallDetector.ets`, `Index.ets` |
| `phone/` | Huawei Phone | `HomePage.ets`, `WatchMonitorService.ets`, `PushService.ets` |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | ArkTS (TypeScript for HarmonyOS) |
| Platform | HarmonyOS 6.0.1 |
| UI Framework | ArkUI (declarative components) |
| Location | `@ohos.geoLocationManager` (GPS/GNSS) |
| Sensors | `@ohos.sensor` (accelerometer) |
| Haptics | `@ohos.vibrator` |
| Notifications | `@kit.NotificationKit` (watch), `@kit.PushKit` (phone) |
| Storage | `@ohos.data.preferences` (local), AGConnect (cloud) |
| Watch ↔ Phone | `@kit.WearEngine` (P2P messaging) |
| Auth | Huawei AGConnect OAuth |
| Build | Hvigor (HarmonyOS build system) |

---


### First Run

1. Open the phone app and log in with a Huawei account
2. Add at least one emergency contact
3. Open the watch app → tap **"Set Home Point"** while standing at the patient's home
4. The anchor is saved — the watch is now monitoring

---
## Project Structure

```
Anchor-Watch-App/
├── entry/                    # Watch module
│   └── src/main/ets/
│       ├── pages/
│       │   ├── Index.ets           # All watch UI (menu, home, geofence, debug)
│       │   └── CommunityCard.ets   # Emergency profile card
│       ├── services/
│       │   ├── GeofenceService.ets     # Core state machine
│       │   ├── RealMotionDetector.ets  # Accelerometer-based motion
│       │   ├── MockMotionDetector.ets  # Emulator mock
│       │   ├── MLFallDetector.ets      # ML fall classifier
│       │   ├── FallDetector.ets        # Threshold fall detector
│       │   └── NotificationService.ets # Haptics + alerts
│       ├── config/
│       │   └── AppConfig.ets       # All tuneable thresholds
│       └── common/
│           └── DriftState.ets      # State enum
│
├── phone/                    # Phone companion module
│   └── src/main/ets/
│       ├── pages/
│       │   ├── HomePage.ets            # Caregiver dashboard
│       │   ├── AlertHistoryPage.ets    # Alert timeline
│       │   └── ContactsPage.ets        # Emergency contacts
│       └── services/
│           ├── WatchMonitorService.ets # Watch connection polling
│           ├── PushService.ets         # Push Kit integration
│           ├── CloudSyncService.ets    # AGConnect cloud sync
│           └── SmsService.ets          # Emergency contact alerts
│
└── AppScope/                 # Shared app metadata
```

---

## Design Principles

- **False negatives are dangerous, false positives are just annoying** — tuned to err on the side of alerting
- **Patient never needs to interact with the app** — caregiver sets up, patient wears
- **"Could a stressed caregiver understand this in 2 seconds?"** — every UI decision is tested against this
- **Privacy-first** — no medical data leaves the device unless an alert fires; standard location permissions only

---

## Known Limitations

- `getCurrentLocation()` times out on the emulator — the app falls back to `getLastLocation()`
- Full cross-device push delivery requires a physical Huawei phone paired with a physical watch
- Cloud functions (SMS to emergency contacts) require an AGConnect project with callable functions deployed
- ML fall detector coefficients are fitted on the [SisFall dataset](http://sistemic.udea.edu.co/en/research/projects/english-falls/) — performance on real users may vary

---

## Team

Built by **Runtime Terrors** for a hackathon.

---

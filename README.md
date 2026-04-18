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

## Getting Started

### Prerequisites

- [Huawei DevEco Studio](https://developer.huawei.com/consumer/en/deveco-studio/) (latest version)
- HarmonyOS SDK 6.0.1 (API 21)
- Huawei developer account (for AGConnect services)

### Setup

1. **Clone the repo**
   ```bash
   git clone https://github.com/runtime-terrors-v2/anchor-watch-app.git
   cd anchor-watch-app
   ```

2. **Open in DevEco Studio**
   - File → Open → select the project root

3. **Configure AGConnect (phone module)**
   - Download your `agconnect-services.json` from the [AppGallery Connect Console](https://developer.huawei.com/consumer/en/console)
   - Replace `phone/src/main/resources/base/rawfile/agconnect-services.json`

4. **Set emulator mode**
   - Open `entry/src/main/ets/config/AppConfig.ets`
   - Set `IS_EMULATOR = true` for emulator testing (uses mock sensors)
   - Set `IS_EMULATOR = false` for a real Huawei Watch

5. **Build & run**
   - Watch: select `entry` module → run on Huawei Watch emulator
   - Phone: select `phone` module → run on Huawei Phone emulator

### First Run

1. Open the phone app and log in with a Huawei account
2. Add at least one emergency contact
3. Open the watch app → tap **"Set Home Point"** while standing at the patient's home
4. The anchor is saved — the watch is now monitoring

---

## Configuration

All thresholds are centralised in `entry/src/main/ets/config/AppConfig.ets`:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `IS_EMULATOR` | `true` | Toggles mock vs. real sensors |
| `DRIFT_RADIUS` | `30m` | Inner safe zone radius |
| `ALERT_RADIUS` | `50m` | Outer alert threshold |
| `GPS_INTERVAL_ACTIVE` | `10s` | GPS poll rate during motion |
| `GPS_INTERVAL_REST` | `60s` | GPS poll rate at rest |
| `MOTION_NET_THRESHOLD` | `1.2 m/s²` | Net acceleration to classify as walking |
| `MOTION_SAMPLE_WINDOW` | `10` | Rolling window size (~2s at 5 Hz) |
| `MOTION_DEBOUNCE_MS` | `2000ms` | Stability required before state change |
| `FALL_IMPACT_THRESHOLD` | `25 m/s²` | Peak G-force to trigger fall check |
| `FALL_STILLNESS_THRESHOLD` | `0.5 m/s²` | Post-fall stillness threshold |
| `ML_FALL_SCORE_THRESHOLD` | `0.5` | Logistic regression confidence cutoff |

---

## Permissions

### Watch (`entry/module.json5`)

| Permission | Reason |
|-----------|--------|
| `LOCATION` | Precise GPS for anchor and distance calculation |
| `APPROXIMATELY_LOCATION` | Required alongside precise location on HarmonyOS |
| `PLACE_CALL` | Tap-to-dial emergency contacts from Community Card |

### Phone (`phone/module.json5`)

| Permission | Reason |
|-----------|--------|
| `INTERNET` | Cloud sync via AGConnect |
| `ACCESS_BLUETOOTH`, `MANAGE_BLUETOOTH` | Watch pairing |
| `KEEP_BACKGROUND_RUNNING` | Monitor watch connection while app is in background |

---

## Testing on the Emulator

GPS can be injected in DevEco Studio's emulator console. Use these steps to test each drift state:

1. **Launch the watch app** and tap "Set Home Point" at your injected start coordinates
2. **Open the debug panel** (long-press "ANCHOR" title for 3 seconds)
3. Tap **"Simulate Walking"** to activate motion detection
4. **Inject GPS coordinates** at ~35m away → should enter `DRIFTING`
5. **Inject GPS coordinates** at ~60m away → should enter `ALERT` with haptics
6. Tap **"Simulate Fall"** to test fall detection independently

> **Note:** The accelerometer cannot be directly injected on the emulator — the debug panel's mock detector substitutes for it. Real watch testing requires a physical Huawei Watch.

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

Built by **Ujwal** for a hackathon.

---

## License

MIT — see [LICENSE](LICENSE) for details.

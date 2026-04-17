// AppConfig.ets
// Central configuration for the ANCHOR app.
// All tuneable thresholds and build-time flags live here so they are easy to adjust.
//
// IMPORTANT: set IS_EMULATOR = false before deploying to a real Huawei Watch.

export class AppConfig {

  // ---------------------------------------------------------------------------
  // Deployment target
  // ---------------------------------------------------------------------------

  // true  → DevEco Studio emulator: uses MockMotionDetector + MockFallDetector
  // false → real Huawei Watch:      uses RealMotionDetector + RealFallDetector
  static readonly IS_EMULATOR: boolean = true;

  // ---------------------------------------------------------------------------
  // Geofence radius thresholds (metres)
  // ---------------------------------------------------------------------------

  // Below this distance: patient is in the SAFE zone
  static readonly DRIFT_RADIUS: number = 30;

  // Beyond this distance (with motion): state escalates to ALERT
  static readonly ALERT_RADIUS: number = 50;

  // ---------------------------------------------------------------------------
  // GPS polling intervals (seconds)
  // ---------------------------------------------------------------------------

  // Faster polling when the accelerometer detects walking — catches exits early
  static readonly GPS_INTERVAL_ACTIVE: number = 10;

  // Slower polling when the patient is still — preserves watch battery
  static readonly GPS_INTERVAL_REST: number = 60;

  // ---------------------------------------------------------------------------
  // Motion detection (accelerometer)
  // ---------------------------------------------------------------------------

  // Net acceleration above gravity (m/s²) required to classify a reading as "moving"
  // Net = |magnitude − 9.8| — removes the constant gravity component
  static readonly MOTION_NET_THRESHOLD: number = 1.2;

  // Rolling window size (number of samples) used for sustained-motion averaging
  // At ~5 Hz (normal interval) this is roughly 2 seconds of data
  static readonly MOTION_SAMPLE_WINDOW: number = 10;

  // A new motion state must persist for this many milliseconds before being committed.
  // Prevents single-jostle or GPS-noise events from flipping the state.
  static readonly MOTION_DEBOUNCE_MS: number = 2000;

  // ---------------------------------------------------------------------------
  // Fall detection (accelerometer)
  // ---------------------------------------------------------------------------

  // Total magnitude (m/s²) that indicates an impact spike — roughly 2.5g
  static readonly FALL_IMPACT_THRESHOLD: number = 25;

  // Net acceleration below this value counts as post-fall stillness (m/s²)
  static readonly FALL_STILLNESS_THRESHOLD: number = 0.5;

  // The patient must remain still for this many ms after the spike to confirm a fall
  static readonly FALL_STILLNESS_DURATION: number = 2000;

  // ---------------------------------------------------------------------------
  // ML Fall Detection — MLFallDetector
  // ---------------------------------------------------------------------------
  // These values control the feature extractor and weighted scoring classifier.
  // They are intentionally separated from the threshold-based FALL_* values above
  // so both detectors can be tuned independently.

  // Number of pre-impact samples to keep in the sliding window.
  // At ~5 Hz (normal sensor interval), 5 samples ≈ 1 second of pre-fall context.
  static readonly ML_PRE_WINDOW_SIZE: number = 5;

  // Number of post-impact samples to collect before classifying.
  // 10 samples ≈ 2 seconds — enough to confirm sustained post-fall stillness.
  static readonly ML_POST_WINDOW_SIZE: number = 10;

  // Safety timeout (ms): if post-impact samples stop arriving (e.g. sensor fault),
  // abandon the candidate after this many ms to avoid the detector getting stuck.
  static readonly ML_POST_TIMEOUT_MS: number = 5000;

  // --- StandardScaler parameters (fitted on SisFall training set) ---
  // Applied at inference time: z_i = (feature_i - mean_i) / scale_i
  // Feature order: [impactPeak, preEnergy, postStillness, postVariance]
  static readonly ML_SCALER_MEAN_0: number  = 44.97959297; // impactPeak mean  (m/s²)
  static readonly ML_SCALER_MEAN_1: number  =  2.64562076; // preEnergy mean   (m/s²)
  static readonly ML_SCALER_MEAN_2: number  =  1.57986326; // postStillness mean (m/s²)
  static readonly ML_SCALER_MEAN_3: number  = 15.89728318; // postVariance mean

  static readonly ML_SCALER_SCALE_0: number = 37.70226793; // impactPeak std
  static readonly ML_SCALER_SCALE_1: number =  2.00469234; // preEnergy std
  static readonly ML_SCALER_SCALE_2: number =  1.43206870; // postStillness std
  static readonly ML_SCALER_SCALE_3: number = 26.19636974; // postVariance std

  // --- Logistic regression coefficients (trained on SisFall) ---
  // logit = COEF_0*z0 + COEF_1*z1 + COEF_2*z2 + COEF_3*z3 + BIAS
  // p_fall = 1 / (1 + exp(-logit))
  static readonly ML_COEF_0: number =  5.98325690; // impactPeak weight  (positive: high impact → fall)
  static readonly ML_COEF_1: number = -0.69412253; // preEnergy weight   (negative: active pre-fall → less likely)
  static readonly ML_COEF_2: number = -0.30814991; // postStillness weight (negative: still post-fall → fall)
  static readonly ML_COEF_3: number = -0.76297909; // postVariance weight (negative: low variance → fall)
  static readonly ML_BIAS:   number =  0.93321737;

  // --- Decision threshold ---
  // p_fall >= this value → fall confirmed.
  // 0.5 = balanced (default logistic regression cutoff).
  // Lower (e.g. 0.35) to improve recall at the cost of more false positives —
  // appropriate for seniors where missing a real fall is the greater risk.
  static readonly ML_FALL_SCORE_THRESHOLD: number = 0.5;
}

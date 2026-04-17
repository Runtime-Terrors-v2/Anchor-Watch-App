// MLFallDetector.ets
// ML-inspired fall detection using a sliding window feature extractor
// and a weighted scoring classifier.
//
// Architecture mirrors a trained binary classifier:
//   Raw samples → Feature extraction → Weighted scoring → Threshold decision
//
// Two-phase detection:
//   IDLE        — maintaining a rolling pre-impact window, watching for a spike
//   POST_IMPACT — collecting post-impact samples; classifies once the window is full
//
// Why this is better than the threshold-only RealFallDetector:
//   The original detector only checks spike magnitude + post-fall stillness duration.
//   This classifier adds two more features — pre-impact energy and post-impact variance —
//   which together distinguish real falls from: dropping the watch, sitting down hard,
//   or bumping into furniture while walking.

import sensor from '@ohos.sensor';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppConfig } from '../config/AppConfig';
import { FallDetector, FallEvent } from './FallDetector';

const DOMAIN = 0x0000;

// ---------------------------------------------------------------------------
// Feature vector
// ---------------------------------------------------------------------------

// Four features extracted from the accelerometer windows around an impact event.
// Separating this into a named interface mirrors the feature vector that would
// be fed into a trained model's input layer — makes it easy to swap in a real
// MindSpore Lite model later without changing the surrounding logic.
//
// Named interface required — ArkTS forbids inline object type literals
// (arkts-no-obj-literals-as-types).
interface FallFeatures {
  impactPeak: number;    // peak acceleration magnitude during the impact spike (m/s²)
  preEnergy: number;     // mean net-accel in the 1s window before impact
  postStillness: number; // mean net-accel in the post-impact window (low = lying still)
  postVariance: number;  // variance of net-accel post-impact (low = sustained stillness)
}

// ---------------------------------------------------------------------------
// MLFallDetector
// ---------------------------------------------------------------------------

// Real-device fall detector using feature extraction + weighted scoring.
// NOT usable on the DevEco Studio emulator — use MockFallDetector when IS_EMULATOR=true.
export class MLFallDetector implements FallDetector {
  private callback: ((event: FallEvent) => void) | null = null;
  private sensorCallback: ((data: sensor.AccelerometerResponse) => void) | null = null;

  // --- Phase state ---
  // true = an impact spike has been detected and we are collecting post-impact samples.
  private inPostImpact: boolean = false;

  // Epoch ms of the detected impact — recorded when the spike is seen, used as the
  // fall event timestamp and for the post-impact safety timeout.
  private impactTime: number = 0;

  // Peak magnitude recorded during the impact phase.
  // Updated throughout post-impact collection in case a second spike follows.
  private impactPeak: number = 0;

  // --- Sliding windows ---

  // Pre-impact window: a rolling buffer of the last ML_PRE_WINDOW_SIZE net-accel samples.
  // Represents the activity level immediately before the impact.
  private preBuffer: number[] = [];

  // Post-impact window: accumulates net-accel samples after the impact spike.
  // Classification runs once this reaches ML_POST_WINDOW_SIZE samples.
  private postBuffer: number[] = [];

  // ---------------------------------------------------------------------------
  // FallDetector interface
  // ---------------------------------------------------------------------------

  startMonitoring(onFall: (event: FallEvent) => void): void {
    this.callback = onFall;
    this.reset();
    try {
      // Subscribe at 'normal' interval (~5 Hz) — same rate as RealFallDetector.
      // ArkTS requires object literals to be explicitly typed (arkts-no-untyped-obj-literals).
      const options: sensor.Options = { interval: 'normal' };
      this.sensorCallback = (data: sensor.AccelerometerResponse) => {
        this.processSample(data.x, data.y, data.z);
      };
      sensor.on(sensor.SensorId.ACCELEROMETER, this.sensorCallback, options);
      hilog.info(DOMAIN, 'MLFallDetector', 'Started — pre-window: %{public}d  post-window: %{public}d',
        AppConfig.ML_PRE_WINDOW_SIZE, AppConfig.ML_POST_WINDOW_SIZE);
    } catch (err) {
      hilog.error(DOMAIN, 'MLFallDetector', 'Sensor start failed: %{public}s', JSON.stringify(err));
    }
  }

  stopMonitoring(): void {
    try {
      sensor.off(sensor.SensorId.ACCELEROMETER);
    } catch (err) {
      hilog.warn(DOMAIN, 'MLFallDetector', 'Sensor stop failed: %{public}s', JSON.stringify(err));
    }
    this.callback = null;
    this.sensorCallback = null;
    this.reset();
    hilog.info(DOMAIN, 'MLFallDetector', 'Stopped');
  }

  // ---------------------------------------------------------------------------
  // Sample processing — finite state machine
  // ---------------------------------------------------------------------------

  private processSample(x: number, y: number, z: number): void {
    const magnitude: number = Math.sqrt(x * x + y * y + z * z);
    // Net acceleration: strip gravity so 0 ≈ completely still, >0 ≈ moving.
    const netAccel: number = Math.abs(magnitude - 9.8);

    if (!this.inPostImpact) {
      // --- IDLE phase ---
      // Maintain the pre-impact sliding window. This gives us a snapshot of what
      // the person was doing in the second before the impact event.
      this.preBuffer.push(netAccel);
      if (this.preBuffer.length > AppConfig.ML_PRE_WINDOW_SIZE) {
        // Drop the oldest sample to keep the window fixed-size.
        this.preBuffer.shift();
      }

      // Watch for an impact spike — this is the trigger to start post-impact collection.
      if (magnitude > AppConfig.FALL_IMPACT_THRESHOLD) {
        this.inPostImpact = true;
        this.impactTime = Date.now();
        this.impactPeak = magnitude;
        this.postBuffer = [];
        hilog.info(DOMAIN, 'MLFallDetector',
          'Impact spike detected: %{public}f m/s² — collecting post window', magnitude);
      }

    } else {
      // --- POST_IMPACT phase ---

      // Update the peak in case a secondary spike follows the primary impact.
      if (magnitude > this.impactPeak) {
        this.impactPeak = magnitude;
      }

      this.postBuffer.push(netAccel);

      // Safety timeout: if the accelerometer stops delivering samples (e.g. sensor
      // dropped mid-event), abandon this candidate after ML_POST_TIMEOUT_MS.
      if (Date.now() - this.impactTime > AppConfig.ML_POST_TIMEOUT_MS) {
        hilog.warn(DOMAIN, 'MLFallDetector', 'Post-impact timeout — discarding candidate');
        this.reset();
        return;
      }

      // Classify once the post-impact window is fully collected.
      if (this.postBuffer.length >= AppConfig.ML_POST_WINDOW_SIZE) {
        this.classifyAndReset();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Feature extraction
  // ---------------------------------------------------------------------------

  // Compute the four feature values from the captured pre- and post-impact buffers.
  private extractFeatures(): FallFeatures {
    // preEnergy: mean net-accel in the sliding window captured before the spike.
    // Low value = person was relatively still before the fall (typical for seniors).
    // High value = person was exercising vigorously (less likely to be a fall).
    let preSum: number = 0;
    for (let i: number = 0; i < this.preBuffer.length; i++) {
      preSum += this.preBuffer[i];
    }
    const preEnergy: number = this.preBuffer.length > 0
      ? preSum / this.preBuffer.length
      : 0;

    // postStillness: mean net-accel in the post-impact window.
    // Low = person is lying flat and not moving — the expected post-fall state.
    let postSum: number = 0;
    for (let i: number = 0; i < this.postBuffer.length; i++) {
      postSum += this.postBuffer[i];
    }
    const postMean: number = this.postBuffer.length > 0
      ? postSum / this.postBuffer.length
      : 0;

    // postVariance: variance of net-accel after impact.
    // Low = stillness is sustained across the whole window (not a brief pause).
    // High = the person is still moving around — probably not a fall.
    let postVarSum: number = 0;
    for (let i: number = 0; i < this.postBuffer.length; i++) {
      const diff: number = this.postBuffer[i] - postMean;
      postVarSum += diff * diff;
    }
    const postVariance: number = this.postBuffer.length > 0
      ? postVarSum / this.postBuffer.length
      : 0;

    // ArkTS requires object literals to be explicitly typed (arkts-no-untyped-obj-literals).
    const features: FallFeatures = {
      impactPeak: this.impactPeak,
      preEnergy: preEnergy,
      postStillness: postMean,
      postVariance: postVariance
    };
    return features;
  }

  // ---------------------------------------------------------------------------
  // Classifier — logistic regression inference
  // ---------------------------------------------------------------------------

  // Extract features from the captured windows, run logistic regression inference,
  // and fire a fall event if the predicted fall probability meets the threshold.
  //
  // Inference steps (mirrors sklearn's predict_proba at runtime):
  //   1. Standardise each feature using the training-set scaler parameters.
  //   2. Compute the linear combination (logit) with the trained coefficients.
  //   3. Apply the sigmoid function to get a fall probability in [0, 1].
  //   4. Compare against ML_FALL_SCORE_THRESHOLD.
  private classifyAndReset(): void {
    const features: FallFeatures = this.extractFeatures();

    hilog.info(DOMAIN, 'MLFallDetector',
      'Features — impactPeak: %.2f  preEnergy: %.2f  postStillness: %.2f  postVariance: %.2f',
      features.impactPeak, features.preEnergy, features.postStillness, features.postVariance);

    // Step 1 — standardise features using scaler parameters from training.
    // z_i = (feature_i - mean_i) / scale_i
    const z0: number = (features.impactPeak    - AppConfig.ML_SCALER_MEAN_0) / AppConfig.ML_SCALER_SCALE_0;
    const z1: number = (features.preEnergy     - AppConfig.ML_SCALER_MEAN_1) / AppConfig.ML_SCALER_SCALE_1;
    const z2: number = (features.postStillness - AppConfig.ML_SCALER_MEAN_2) / AppConfig.ML_SCALER_SCALE_2;
    const z3: number = (features.postVariance  - AppConfig.ML_SCALER_MEAN_3) / AppConfig.ML_SCALER_SCALE_3;

    // Step 2 — linear combination with trained coefficients.
    // logit = w0*z0 + w1*z1 + w2*z2 + w3*z3 + bias
    const logit: number =
      AppConfig.ML_COEF_0 * z0 +
      AppConfig.ML_COEF_1 * z1 +
      AppConfig.ML_COEF_2 * z2 +
      AppConfig.ML_COEF_3 * z3 +
      AppConfig.ML_BIAS;

    // Step 3 — sigmoid: maps logit to a fall probability in [0, 1].
    const pFall: number = 1.0 / (1.0 + Math.exp(-logit));

    hilog.info(DOMAIN, 'MLFallDetector',
      'Standardised — z0: %.2f  z1: %.2f  z2: %.2f  z3: %.2f  logit: %.3f  p(fall): %.3f  threshold: %.2f',
      z0, z1, z2, z3, logit, pFall, AppConfig.ML_FALL_SCORE_THRESHOLD);

    if (pFall >= AppConfig.ML_FALL_SCORE_THRESHOLD) {
      hilog.warn(DOMAIN, 'MLFallDetector', 'Fall confirmed — p(fall)=%.3f', pFall);
      this.fireFallEvent();
    } else {
      hilog.info(DOMAIN, 'MLFallDetector',
        'Impact discarded — p(fall)=%.3f below threshold %.2f', pFall, AppConfig.ML_FALL_SCORE_THRESHOLD);
    }

    this.reset();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  private fireFallEvent(): void {
    if (this.callback !== null) {
      // Use impactTime as the event timestamp — that is the moment of the fall,
      // not the moment classification completed (which is ~2s later).
      // ArkTS requires object literals to be explicitly typed (arkts-no-untyped-obj-literals).
      const event: FallEvent = {
        detected: true,
        timestamp: this.impactTime
      };
      this.callback(event);
    }
  }

  // Reset all phase state and buffers — called after every classification
  // and at startup/shutdown so the detector is always in a clean state.
  private reset(): void {
    this.inPostImpact = false;
    this.impactTime = 0;
    this.impactPeak = 0;
    this.preBuffer = [];
    this.postBuffer = [];
  }
}

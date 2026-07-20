#pragma once
// Hardware + protocol config for nn-follow-cart
// Pin map: docs/pinout.md · BTS7960: docs/hardware/bts7960-pinout.md
// Dual-ESP: docs/firmware/dual-esp-direction-plan.md

// ---- Role (platformio env) ----
// Primary owns motors + phone GATT + ESP-NOW RX.
// Secondary is BLE ear only + ESP-NOW TX.
#if defined(NN_ROLE_SECONDARY)
#  define NN_IS_PRIMARY 0
#else
#  define NN_IS_PRIMARY 1
#endif

// ---- Device identity ----
// App scan filter still matches names containing "NN-CART".
#ifndef NN_DEVICE_NAME
#  if NN_IS_PRIMARY
#    define NN_DEVICE_NAME "NN-Follow-Cart"
#  else
#    define NN_DEVICE_NAME "NN-Follow-Cart-S"
#  endif
#endif

// ---- BLE UUIDs (phone app must match) ----
#define CART_SERVICE_UUID        "A1B2C3D4-E5F6-7890-ABCD-EF1234567890"
#define TELEMETRY_CHAR_UUID      "A1B2C3D4-E5F6-7890-ABCD-EF1234567891"
#define CONTROL_CHAR_UUID        "A1B2C3D4-E5F6-7890-ABCD-EF1234567892"
#define CONFIG_CHAR_UUID         "A1B2C3D4-E5F6-7890-ABCD-EF1234567893"

#define CTRL_STOP     0x00
#define CTRL_FOLLOW   0x01
#define CTRL_HALT     0x02
#define CTRL_DRIVE    0x10  // manual: [0x10, left_i8, right_i8] pct −100…100

// Drop manual drive if no CTRL_DRIVE refresh
static const int DRIVE_TIMEOUT_MS = 400;

// Telemetry status (v1 packet still 8 bytes)
#define ST_FOLLOWING     0x01
#define ST_CONNECTED     0x02
#define ST_LOW_BATT      0x04
#define ST_HALTED        0x08
#define ST_SIGNAL_LOST   0x10
#define ST_STEREO_OK     0x20  // secondary sample fresh
#define ST_STEREO_DEGRADED 0x40

// ---- Pins (primary BTS7960 cargo drive) ----
static const int PIN_RPWM_LEFT  = 25;
static const int PIN_LPWM_LEFT  = 14;
static const int PIN_RPWM_RIGHT = 26;
static const int PIN_LPWM_RIGHT = 27;
static const int PIN_MOT_EN     = 4;

static const int PIN_BATT_ADC   = 36;
static const int PIN_STATUS_LED = 13;
static const int PIN_BUZZER     = 5;

// UART fallback reserved (ESP-NOW default)
static const int PIN_LINK_TX = 17;
static const int PIN_LINK_RX = 16;

// ---- Motor PWM (LEDC) ----
static const int PWM_FREQ_HZ   = 20000;
static const int PWM_RES_BITS  = 8;
static const int PWM_CH_RPWM_L = 0;
static const int PWM_CH_RPWM_R = 1;
static const int PWM_CH_LPWM_L = 2;
static const int PWM_CH_LPWM_R = 3;
static const int MAX_SPEED     = 180;  // of 255 — cargo soft cap

// ---- Follow / path-loss ----
static const float RSSI_TX_1M     = -59.0f;
static const float PATH_LOSS_N    = 2.0f;
static const float TARGET_DIST_M  = 2.0f;
static const float DEADBAND_M     = 0.30f;
static const float MAX_FOLLOW_M   = 6.0f;
static const float MIN_FOLLOW_M   = 0.5f;
static const int   SIGNAL_LOST_MS = 3000;
static const int   TELEMETRY_MS   = 200;
static const int   CONTROL_MS     = 50;
static const int   RSSI_POLL_MS   = 100;

// Longitudinal gain (distance error m → % speed)
static const float GAIN_DIST      = 35.0f;

// ---- Stereo steer (primary left, secondary right) ----
// Δ = rssi_left - rssi_right (dB). Δ>0 → phone stronger left → turn left.
static const float GAIN_STEER     = 4.0f;   // dB → % bias
static const float STEER_DEAD_DB  = 2.0f;   // ignore |Δ| below
static const int   STEER_MAX      = 45;     // max |w| percent
static const float STEER_LP_ALPHA = 0.25f;  // low-pass on Δ
static const int   STEREO_FRESH_MS = 300;   // ESP-NOW age → ST_STEREO_OK
static const int   STEREO_STALE_MS = 150;   // drop sample for fuse
static const int   LINK_TX_MS     = 50;     // secondary publish ~20 Hz

// ESP-NOW fixed channel (1–13)
static const int   LINK_NOW_CHANNEL = 1;

// Battery divider (ADC volts at pack full/empty — calibrate for 12 V LFP)
static const float BATT_ADC_FULL  = 3.10f;
static const float BATT_ADC_EMPTY = 2.20f;
static const float BATT_VREF      = 3.3f;
static const int   BATT_SAMPLES   = 8;

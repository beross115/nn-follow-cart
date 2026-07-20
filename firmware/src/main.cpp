/**
 * Primary ESP — motors (BTS7960) + phone GATT + ESP-NOW stereo fuse.
 * Protocol: docs/firmware/ble-protocol.md
 * Dual-ESP: docs/firmware/dual-esp-direction-plan.md
 * Pins:     docs/hardware/bts7960-pinout.md
 */
#include <Arduino.h>
#include <NimBLEDevice.h>
#include <cmath>

#include "config.h"
#include "motors.h"
#include "battery.h"
#include "telemetry.h"
#include "link_now.h"

extern "C" int ble_gap_conn_rssi(uint16_t conn_handle, int8_t *out_rssi);

static const uint16_t kNoConn = 0xFFFF;

static volatile bool g_following = false;
static volatile bool g_halted = false;
static volatile bool g_connected = false;
static volatile bool g_manual = false;
static volatile int8_t g_manualL = 0;
static volatile int8_t g_manualR = 0;
static volatile uint32_t g_lastDriveMs = 0;
static volatile int8_t g_rssi = -90;
static volatile uint32_t g_lastRssiMs = 0;
static volatile uint16_t g_connHandle = kNoConn;
static uint8_t g_seq = 0;
static float g_distanceM = 0.0f;
static float g_deltaFilt = 0.0f;
static float g_deltaZero = 0.0f;  // set when cal added; 0 default
static int8_t g_rssiSec = -127;
static bool g_stereoOk = false;

static NimBLEServer *g_server = nullptr;
static NimBLECharacteristic *g_telemChar = nullptr;

static float rssiToMeters(int rssi) {
  float exp = (RSSI_TX_1M - (float)rssi) / (10.0f * PATH_LOSS_N);
  float d = powf(10.0f, exp);
  if (d < 0.1f) d = 0.1f;
  if (d > 20.0f) d = 20.0f;
  return d;
}

static int clampi(int v, int lo, int hi) {
  if (v < lo) return lo;
  if (v > hi) return hi;
  return v;
}

static void followControlLoop() {
  uint32_t now = millis();

  if (g_halted || !g_connected) {
    g_manual = false;
    motorsStop();
    return;
  }

  // Manual joystick preempts FOLLOW until timeout or STOP/HALT
  if (g_manual) {
    if (now - g_lastDriveMs > (uint32_t)DRIVE_TIMEOUT_MS) {
      g_manual = false;
      g_manualL = g_manualR = 0;
      motorsStop();
    } else {
      motorsSet((int)g_manualL, (int)g_manualR);
    }
    return;
  }

  if (!g_following) {
    motorsStop();
    return;
  }

  if (now - g_lastRssiMs > (uint32_t)SIGNAL_LOST_MS) {
    motorsStop();
    return;
  }

  float d = g_distanceM;
  if (d > MAX_FOLLOW_M) {
    motorsStop();
    return;
  }

  float err = d - TARGET_DIST_M;
  int v = 0;
  if (fabsf(err) > DEADBAND_M) {
    v = (int)(err * GAIN_DIST);
    v = clampi(v, -60, 100);
  }
  if (d < MIN_FOLLOW_M) v = -30;

  // Stereo turn bias (optional if secondary fresh)
  int w = 0;
  StereoSample sec{};
  uint32_t age = 0;
  g_stereoOk = false;
  if (linkNowLatest(sec, &age) && age <= (uint32_t)STEREO_FRESH_MS &&
      !(sec.flags & STEREO_F_SIGNAL_STALE)) {
    g_stereoOk = true;
    g_rssiSec = sec.rssi_dbm;
    float delta = (float)g_rssi - (float)sec.rssi_dbm - g_deltaZero;
    g_deltaFilt = STEER_LP_ALPHA * delta + (1.0f - STEER_LP_ALPHA) * g_deltaFilt;
    if (fabsf(g_deltaFilt) >= STEER_DEAD_DB) {
      w = clampi((int)(g_deltaFilt * GAIN_STEER), -STEER_MAX, STEER_MAX);
    }
  } else {
    g_deltaFilt *= 0.9f;  // decay turn bias if ear lost
  }

  int left = clampi(v - w, -100, 100);
  int right = clampi(v + w, -100, 100);
  motorsSet(left, right);
}

class ServerCallbacks : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer *s, ble_gap_conn_desc *desc) {
    (void)s;
    g_connected = true;
    g_connHandle = desc ? desc->conn_handle : kNoConn;
    g_lastRssiMs = millis();
    Serial.printf("[BLE] connected handle=%u\n", g_connHandle);
    digitalWrite(PIN_STATUS_LED, HIGH);
    NimBLEDevice::stopAdvertising();
  }

  void onDisconnect(NimBLEServer *s, ble_gap_conn_desc *desc) {
    (void)s;
    (void)desc;
    g_connected = false;
    g_following = false;
    g_manual = false;
    g_manualL = g_manualR = 0;
    g_connHandle = kNoConn;
    motorsStop();
    Serial.println("[BLE] disconnected — re-advertise");
    digitalWrite(PIN_STATUS_LED, LOW);
    delay(100);
    NimBLEDevice::startAdvertising();
  }
};

class ControlCallbacks : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic *c) {
    std::string val = c->getValue();
    if (val.empty()) return;
    uint8_t op = (uint8_t)val[0];
    switch (op) {
      case CTRL_STOP:
        g_following = false;
        g_manual = false;
        g_manualL = g_manualR = 0;
        g_halted = false;
        motorsStop();
        Serial.println("[CTRL] STOP");
        break;
      case CTRL_FOLLOW:
        g_halted = false;
        g_manual = false;
        g_manualL = g_manualR = 0;
        g_following = true;
        Serial.println("[CTRL] FOLLOW");
        break;
      case CTRL_HALT:
        g_halted = true;
        g_following = false;
        g_manual = false;
        g_manualL = g_manualR = 0;
        motorsStop();
        Serial.println("[CTRL] HALT");
        digitalWrite(PIN_BUZZER, HIGH);
        delay(80);
        digitalWrite(PIN_BUZZER, LOW);
        break;
      case CTRL_DRIVE:
        if (val.size() < 3) {
          Serial.println("[CTRL] DRIVE needs 3 bytes");
          break;
        }
        if (g_halted) break;
        g_following = false;  // joystick takes over
        g_manual = true;
        g_manualL = (int8_t)val[1];
        g_manualR = (int8_t)val[2];
        g_lastDriveMs = millis();
        break;
      default:
        Serial.printf("[CTRL] unknown 0x%02X\n", op);
        break;
    }
  }
};

static void setupBle() {
  NimBLEDevice::init(NN_DEVICE_NAME);
  NimBLEDevice::setPower(ESP_PWR_LVL_P9);
  NimBLEDevice::setSecurityAuth(false, false, false);
  NimBLEDevice::setMTU(185);

  g_server = NimBLEDevice::createServer();
  g_server->setCallbacks(new ServerCallbacks());

  NimBLEService *svc = g_server->createService(CART_SERVICE_UUID);

  g_telemChar = svc->createCharacteristic(
      TELEMETRY_CHAR_UUID, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY);

  NimBLECharacteristic *ctrl = svc->createCharacteristic(
      CONTROL_CHAR_UUID, NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR);
  ctrl->setCallbacks(new ControlCallbacks());

  NimBLECharacteristic *cfg = svc->createCharacteristic(
      CONFIG_CHAR_UUID, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::WRITE);
  uint16_t targetCm = (uint16_t)(TARGET_DIST_M * 100.0f);
  cfg->setValue((uint8_t *)&targetCm, sizeof(targetCm));

  svc->start();

  NimBLEAdvertising *adv = NimBLEDevice::getAdvertising();
  adv->addServiceUUID(CART_SERVICE_UUID);
  adv->setName(NN_DEVICE_NAME);
  adv->setScanResponse(true);
  adv->start();

  Serial.printf("[BLE] advertising as %s\n", NN_DEVICE_NAME);
}

static void updateConnectedRssi() {
  if (!g_connected || g_connHandle == kNoConn) return;
  int8_t rssi = -100;
  if (ble_gap_conn_rssi(g_connHandle, &rssi) == 0) {
    g_rssi = rssi;
    g_lastRssiMs = millis();
    g_distanceM = rssiToMeters(g_rssi);
  }
}

static void publishTelemetry() {
  TelemetryPacket pkt{};
  pkt.rssi = g_rssi;
  float d = g_distanceM;
  if (d < 0) d = 0;
  if (d > 655.0f) d = 655.0f;
  pkt.distance_cm = (uint16_t)(d * 100.0f + 0.5f);
  pkt.battery = batteryPercent();
  pkt.status = 0;
  if (g_following) pkt.status |= ST_FOLLOWING;
  if (g_connected) pkt.status |= ST_CONNECTED;
  if (pkt.battery <= 20) pkt.status |= ST_LOW_BATT;
  if (g_halted) pkt.status |= ST_HALTED;
  if (g_connected && (millis() - g_lastRssiMs > (uint32_t)SIGNAL_LOST_MS)) {
    pkt.status |= ST_SIGNAL_LOST;
  }
  if (g_stereoOk) {
    pkt.status |= ST_STEREO_OK;
  } else {
    pkt.status |= ST_STEREO_DEGRADED;
  }
  int ml = 0, mr = 0;
  motorsGet(ml, mr);
  pkt.motor_left = (int8_t)ml;
  pkt.motor_right = (int8_t)mr;
  pkt.seq = g_seq++;

  if (g_telemChar) {
    g_telemChar->setValue((uint8_t *)&pkt, sizeof(pkt));
    if (g_connected) g_telemChar->notify();
  }

  static uint32_t lastLog = 0;
  if (millis() - lastLog > 1000) {
    lastLog = millis();
    Serial.printf("[P] rssi=%d sec=%d d=%.2f dF=%.1f stereo=%d nowRx=%u L=%d R=%d\n",
                  (int)g_rssi, (int)g_rssiSec, g_distanceM, g_deltaFilt,
                  (int)g_stereoOk, (unsigned)linkNowRxCount(), ml, mr);
  }
}

void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println("\n=== nn-follow-cart PRIMARY ===");

  pinMode(PIN_STATUS_LED, OUTPUT);
  pinMode(PIN_BUZZER, OUTPUT);
  digitalWrite(PIN_STATUS_LED, LOW);
  digitalWrite(PIN_BUZZER, LOW);

  motorsBegin();
  batteryBegin();
  linkNowBegin(true);
  setupBle();

  Serial.println("[BOOT] primary ready — phone GATT + ESP-NOW ear RX");
}

void loop() {
  static uint32_t lastTelem = 0;
  static uint32_t lastCtrl = 0;
  static uint32_t lastRssiPoll = 0;
  uint32_t now = millis();

  if (now - lastRssiPoll >= (uint32_t)RSSI_POLL_MS) {
    lastRssiPoll = now;
    updateConnectedRssi();
  }
  if (now - lastCtrl >= (uint32_t)CONTROL_MS) {
    lastCtrl = now;
    followControlLoop();
  }
  if (now - lastTelem >= (uint32_t)TELEMETRY_MS) {
    lastTelem = now;
    publishTelemetry();
  }

  if (g_following) {
    digitalWrite(PIN_STATUS_LED, (now / 200) % 2);
  } else if (g_connected) {
    digitalWrite(PIN_STATUS_LED, HIGH);
  }

  delay(5);
}

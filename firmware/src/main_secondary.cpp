/**
 * Secondary ESP — BLE ear only. Phone may dual-connect for connection RSSI.
 * Streams StereoSample → primary via ESP-NOW. NO motors.
 */
#include <Arduino.h>
#include <NimBLEDevice.h>

#include "config.h"
#include "link_now.h"

extern "C" int ble_gap_conn_rssi(uint16_t conn_handle, int8_t *out_rssi);

static const uint16_t kNoConn = 0xFFFF;

static volatile bool g_connected = false;
static volatile int8_t g_rssi = -100;
static volatile uint32_t g_lastRssiMs = 0;
static volatile uint16_t g_connHandle = kNoConn;
static uint8_t g_seq = 0;

// Minimal service so phone dual-connects and we get connection RSSI.
// Same UUIDs as primary but secondary ignores control writes for motors.
static NimBLEServer *g_server = nullptr;

class ServerCallbacks : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer *s, ble_gap_conn_desc *desc) {
    (void)s;
    g_connected = true;
    g_connHandle = desc ? desc->conn_handle : kNoConn;
    g_lastRssiMs = millis();
    Serial.printf("[BLE-S] connected handle=%u\n", g_connHandle);
    digitalWrite(PIN_STATUS_LED, HIGH);
    // Keep advertising optional second phones? stop for stability.
    NimBLEDevice::stopAdvertising();
  }

  void onDisconnect(NimBLEServer *s, ble_gap_conn_desc *desc) {
    (void)s;
    (void)desc;
    g_connected = false;
    g_connHandle = kNoConn;
    Serial.println("[BLE-S] disconnected — re-advertise");
    digitalWrite(PIN_STATUS_LED, LOW);
    delay(100);
    NimBLEDevice::startAdvertising();
  }
};

static void setupBle() {
  NimBLEDevice::init(NN_DEVICE_NAME);
  NimBLEDevice::setPower(ESP_PWR_LVL_P9);
  NimBLEDevice::setSecurityAuth(false, false, false);
  NimBLEDevice::setMTU(185);

  g_server = NimBLEDevice::createServer();
  g_server->setCallbacks(new ServerCallbacks());

  // Lightweight service — enough for a connection + RSSI.
  NimBLEService *svc = g_server->createService(CART_SERVICE_UUID);
  NimBLECharacteristic *ping = svc->createCharacteristic(
      TELEMETRY_CHAR_UUID, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY);
  uint8_t z = 0;
  ping->setValue(&z, 1);
  svc->start();

  NimBLEAdvertising *adv = NimBLEDevice::getAdvertising();
  adv->addServiceUUID(CART_SERVICE_UUID);
  adv->setName(NN_DEVICE_NAME);
  adv->setScanResponse(true);
  adv->start();

  Serial.printf("[BLE-S] advertising as %s\n", NN_DEVICE_NAME);
}

static void pollRssi() {
  if (!g_connected || g_connHandle == kNoConn) return;
  int8_t rssi = -100;
  if (ble_gap_conn_rssi(g_connHandle, &rssi) == 0) {
    g_rssi = rssi;
    g_lastRssiMs = millis();
  }
}

static void publishNow() {
  StereoSample s{};
  s.magic = STEREO_MAGIC;
  s.ver = STEREO_VER;
  s.seq = g_seq++;
  s.rssi_dbm = g_rssi;
  s.t_ms = millis();
  s.flags = 0;
  if (g_connected) s.flags |= STEREO_F_PHONE_CONN;
  if (!g_connected || (millis() - g_lastRssiMs > (uint32_t)SIGNAL_LOST_MS)) {
    s.flags |= STEREO_F_SIGNAL_STALE;
  }
  s.crc8 = stereoCrc8(s);
  s.reserved[0] = s.reserved[1] = 0;
  if (!linkNowSend(s)) {
    Serial.println("[NOW-S] send fail");
  }
}

void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println("\n=== nn-follow-cart SECONDARY (ear) ===");

  pinMode(PIN_STATUS_LED, OUTPUT);
  digitalWrite(PIN_STATUS_LED, LOW);

  // No motors, no battery task — ear-only board.
  linkNowBegin(false);
  setupBle();

  Serial.println("[BOOT] secondary ready — connect phone or leave for dual-central later");
}

void loop() {
  static uint32_t lastPoll = 0;
  static uint32_t lastTx = 0;
  uint32_t now = millis();

  if (now - lastPoll >= (uint32_t)RSSI_POLL_MS) {
    lastPoll = now;
    pollRssi();
  }
  if (now - lastTx >= (uint32_t)LINK_TX_MS) {
    lastTx = now;
    // Only stream when we have a phone link; primary ignores stale flags too.
    if (g_connected) {
      publishNow();
    }
  }

  if (g_connected) {
    digitalWrite(PIN_STATUS_LED, (now / 500) % 2);
  }

  delay(5);
}

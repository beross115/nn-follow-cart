#include "link_now.h"
#include "config.h"

#include <WiFi.h>
#include <esp_now.h>
#include <esp_wifi.h>
#include <string.h>

static const uint8_t kBcast[6] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};

static volatile bool g_have = false;
static StereoSample g_latest{};
static volatile uint32_t g_rxMs = 0;
static volatile uint32_t g_rxCount = 0;
static bool g_isPrimary = false;

uint8_t stereoCrc8(const StereoSample &s) {
  // CRC-8/ATM over first 9 payload bytes (magic..flags)
  const uint8_t *p = reinterpret_cast<const uint8_t *>(&s);
  uint8_t crc = 0x00;
  for (int i = 0; i < 9; i++) {
    crc ^= p[i];
    for (int b = 0; b < 8; b++) {
      crc = (crc & 0x80) ? (uint8_t)((crc << 1) ^ 0x07) : (uint8_t)(crc << 1);
    }
  }
  return crc;
}

static bool sampleValid(const StereoSample &s) {
  if (s.magic != STEREO_MAGIC || s.ver != STEREO_VER) return false;
  return stereoCrc8(s) == s.crc8;
}

#if defined(ESP_IDF_VERSION_MAJOR) && (ESP_IDF_VERSION_MAJOR >= 5)
static void onRecv(const esp_now_recv_info_t *info, const uint8_t *data, int len) {
  (void)info;
#else
static void onRecv(const uint8_t *mac, const uint8_t *data, int len) {
  (void)mac;
#endif
  if (!g_isPrimary || len < (int)sizeof(StereoSample)) return;
  StereoSample s;
  memcpy(&s, data, sizeof(s));
  if (!sampleValid(s)) return;
  noInterrupts();
  g_latest = s;
  g_rxMs = millis();
  g_have = true;
  g_rxCount++;
  interrupts();
}

bool linkNowBegin(bool primary) {
  g_isPrimary = primary;

  WiFi.mode(WIFI_STA);
  WiFi.disconnect(true, true);
  delay(50);

  // Fixed channel helps coexistence; BLE leans on different radio path.
  esp_wifi_set_promiscuous(true);
  esp_wifi_set_channel(LINK_NOW_CHANNEL, WIFI_SECOND_CHAN_NONE);
  esp_wifi_set_promiscuous(false);

  if (esp_now_init() != ESP_OK) {
    Serial.println("[NOW] esp_now_init failed");
    return false;
  }

  esp_now_register_recv_cb(onRecv);

  esp_now_peer_info_t peer{};
  memcpy(peer.peer_addr, kBcast, 6);
  peer.channel = LINK_NOW_CHANNEL;
  peer.encrypt = false;
  if (!esp_now_is_peer_exist(kBcast)) {
    if (esp_now_add_peer(&peer) != ESP_OK) {
      Serial.println("[NOW] add broadcast peer failed");
      return false;
    }
  }

  linkNowLogMac(primary ? "primary" : "secondary");
  Serial.printf("[NOW] ready role=%s ch=%u\n", primary ? "P" : "S", LINK_NOW_CHANNEL);
  return true;
}

bool linkNowSend(const StereoSample &s) {
  return esp_now_send(kBcast, reinterpret_cast<const uint8_t *>(&s), sizeof(s)) == ESP_OK;
}

bool linkNowHaveFresh(uint32_t maxAgeMs) {
  if (!g_have) return false;
  return (millis() - g_rxMs) <= maxAgeMs;
}

bool linkNowLatest(StereoSample &out, uint32_t *ageMs) {
  if (!g_have) return false;
  noInterrupts();
  out = g_latest;
  uint32_t age = millis() - g_rxMs;
  interrupts();
  if (ageMs) *ageMs = age;
  return true;
}

uint32_t linkNowRxCount() { return g_rxCount; }

void linkNowLogMac(const char *tag) {
  Serial.printf("[NOW] %s MAC %s\n", tag, WiFi.macAddress().c_str());
}

#pragma once
#include <Arduino.h>
#include <stdint.h>

// ESP-NOW stereo sample (secondary → primary). Little-endian packed.
// Plan: docs/firmware/dual-esp-direction-plan.md
struct __attribute__((packed)) StereoSample {
  uint8_t magic;    // 0xA5
  uint8_t ver;      // 1
  uint8_t seq;
  int8_t  rssi_dbm;
  uint32_t t_ms;    // secondary millis
  uint8_t flags;    // bit0 phone_connected, bit1 signal_stale
  uint8_t crc8;     // simple CRC over bytes 0..8 (magic..flags)
  uint8_t reserved[2];
};
static_assert(sizeof(StereoSample) == 12, "StereoSample must be 12 bytes");

#define STEREO_MAGIC           0xA5
#define STEREO_VER             1
#define STEREO_F_PHONE_CONN    0x01
#define STEREO_F_SIGNAL_STALE  0x02

uint8_t stereoCrc8(const StereoSample &s);

// Wi‑Fi STA + ESP-NOW. Safe alongside NimBLE if rate stays modest.
bool linkNowBegin(bool primary);

// Secondary: send sample (broadcast peer). Returns true if esp_now_send ok.
bool linkNowSend(const StereoSample &s);

// Primary: latest accepted sample.
bool linkNowHaveFresh(uint32_t maxAgeMs);
bool linkNowLatest(StereoSample &out, uint32_t *ageMs);
uint32_t linkNowRxCount();

// Print local STA MAC once for peer notes.
void linkNowLogMac(const char *tag);

#pragma once
#include <Arduino.h>

// v1 telemetry 8 bytes — docs/firmware/ble-protocol.md
// status bits include ST_STEREO_OK (0x20) / ST_STEREO_DEGRADED (0x40) on primary.
struct __attribute__((packed)) TelemetryPacket {
  int8_t  rssi;
  uint16_t distance_cm;
  uint8_t battery;
  uint8_t status;
  int8_t  motor_left;
  int8_t  motor_right;
  uint8_t seq;
};
static_assert(sizeof(TelemetryPacket) == 8, "TelemetryPacket must be 8 bytes");

#pragma once
#include <Arduino.h>

void batteryBegin();
// 0-100, clamped. Returns 255 if ADC looks unusable (no divider / floating).
uint8_t batteryPercent();
float batteryAdcVolts();

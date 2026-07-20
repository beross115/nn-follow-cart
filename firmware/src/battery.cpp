#include "battery.h"
#include "config.h"

void batteryBegin() {
  // GPIO36 is input-only ADC1
  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);
  pinMode(PIN_BATT_ADC, INPUT);
}

float batteryAdcVolts() {
  uint32_t acc = 0;
  for (int i = 0; i < BATT_SAMPLES; i++) {
    acc += analogRead(PIN_BATT_ADC);
    delay(2);
  }
  float raw = acc / float(BATT_SAMPLES);
  // 12-bit, 11dB ~ 0-3.3V full scale (approx; ESP32 ADC is nonlinear)
  return (raw / 4095.0f) * BATT_VREF;
}

uint8_t batteryPercent() {
  float v = batteryAdcVolts();
  // Floating / unconnected ADC tends to read near mid or noisy low
  if (v < 0.15f) {
    return 100;  // no pack sense yet — report full so app doesn't panic
  }
  float pct = (v - BATT_ADC_EMPTY) / (BATT_ADC_FULL - BATT_ADC_EMPTY) * 100.0f;
  if (pct < 0) pct = 0;
  if (pct > 100) pct = 100;
  return (uint8_t)(pct + 0.5f);
}

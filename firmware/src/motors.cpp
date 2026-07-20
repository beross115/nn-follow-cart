#include "motors.h"
#include "config.h"

static int g_left = 0;
static int g_right = 0;
static bool g_enabled = false;

static int clampPct(int v) {
  if (v > 100) return 100;
  if (v < -100) return -100;
  return v;
}

static void writePair(int pct, int chFwd, int chRev) {
  pct = clampPct(pct);
  int duty = 0;
  if (pct > 0) {
    duty = (pct * MAX_SPEED) / 100;
    if (duty > 255) duty = 255;
    ledcWrite(chFwd, duty);
    ledcWrite(chRev, 0);
  } else if (pct < 0) {
    duty = ((-pct) * MAX_SPEED) / 100;
    if (duty > 255) duty = 255;
    ledcWrite(chFwd, 0);
    ledcWrite(chRev, duty);
  } else {
    ledcWrite(chFwd, 0);
    ledcWrite(chRev, 0);
  }
}

void motorsBegin() {
  pinMode(PIN_MOT_EN, OUTPUT);
  digitalWrite(PIN_MOT_EN, LOW);

  ledcSetup(PWM_CH_RPWM_L, PWM_FREQ_HZ, PWM_RES_BITS);
  ledcSetup(PWM_CH_RPWM_R, PWM_FREQ_HZ, PWM_RES_BITS);
  ledcSetup(PWM_CH_LPWM_L, PWM_FREQ_HZ, PWM_RES_BITS);
  ledcSetup(PWM_CH_LPWM_R, PWM_FREQ_HZ, PWM_RES_BITS);

  ledcAttachPin(PIN_RPWM_LEFT, PWM_CH_RPWM_L);
  ledcAttachPin(PIN_RPWM_RIGHT, PWM_CH_RPWM_R);
  ledcAttachPin(PIN_LPWM_LEFT, PWM_CH_LPWM_L);
  ledcAttachPin(PIN_LPWM_RIGHT, PWM_CH_LPWM_R);

  motorsEnable(true);
  motorsStop();
}

void motorsEnable(bool on) {
  g_enabled = on;
  digitalWrite(PIN_MOT_EN, on ? HIGH : LOW);
  if (!on) {
    ledcWrite(PWM_CH_RPWM_L, 0);
    ledcWrite(PWM_CH_RPWM_R, 0);
    ledcWrite(PWM_CH_LPWM_L, 0);
    ledcWrite(PWM_CH_LPWM_R, 0);
    g_left = g_right = 0;
  }
}

void motorsStop() {
  g_left = g_right = 0;
  ledcWrite(PWM_CH_RPWM_L, 0);
  ledcWrite(PWM_CH_RPWM_R, 0);
  ledcWrite(PWM_CH_LPWM_L, 0);
  ledcWrite(PWM_CH_LPWM_R, 0);
}

void motorsSet(int leftPct, int rightPct) {
  if (!g_enabled) {
    motorsStop();
    return;
  }
  g_left = clampPct(leftPct);
  g_right = clampPct(rightPct);
  writePair(g_left, PWM_CH_RPWM_L, PWM_CH_LPWM_L);
  writePair(g_right, PWM_CH_RPWM_R, PWM_CH_LPWM_R);
}

void motorsGet(int &leftPct, int &rightPct) {
  leftPct = g_left;
  rightPct = g_right;
}

#pragma once
#include <Arduino.h>

void motorsBegin();
void motorsStop();
void motorsEnable(bool on);
// speed: -100..100 percent (negative = reverse)
void motorsSet(int leftPct, int rightPct);
void motorsGet(int &leftPct, int &rightPct);

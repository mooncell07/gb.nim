#pragma once
#include <stdbool.h>
#include <stdint.h>

typedef struct {
    uint8_t P1;
    uint8_t keyState;
    uint8_t keyMask;
} JoypadState;

extern JoypadState js;

void unsetKey(int key);
void setKey(int key);
void setKeyMask();

#pragma once
#include <stdbool.h>
#include <stdint.h>

extern uint8_t vram[0x2000];
extern uint8_t oam[0x100];

uint8_t ppuReadByte(uint16_t address, bool obj);
void ppuWriteByte(uint16_t address, uint8_t data, bool obj);

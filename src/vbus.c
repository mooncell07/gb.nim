#include "vbus.h"

#include <stdint.h>

uint8_t vram[0x2000];
uint8_t oam[0x100];

uint8_t ppuReadByte(uint16_t address, bool obj) {
    if (obj) {
        return oam[address - 0xFE00];
    } else {
        return vram[address - 0x8000];
    }
}

void ppuWriteByte(uint16_t address, uint8_t data, bool obj) {
    if (obj) {
        oam[address - 0xFE00] = data;
    } else {
        vram[address - 0x8000] = data;
    }
}

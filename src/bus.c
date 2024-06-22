
#include <stdbool.h>
#include <stdint.h>

#include "cartridge.h"
#include "io.h"
#include "mmu.h"
#include "timer.h"
#include "utils.h"
#include "vbus.h"

typedef struct {
    bool active;
    uint8_t currentByte;
    uint8_t currentIndex;
    bool starting;
    uint8_t initialDelay;
} DMA;

void dma_tick(DMA *d);
DMA dma = {0};

void busCycle(bool incr) {
    if (!incr) {
        return;
    }

    if (dma.active) {
        dma_tick(&dma);
    }

    incCycle(1);

    if (dma.starting) {
        if (dma.initialDelay > 1) {
            dma.initialDelay -= 1;
        } else {
            dma.starting = false;
            dma.active = true;
        }
    }
}

uint8_t readByte(uint16_t address, bool incr, bool conflict) {
    uint8_t result = 0;
    if (dma.active && !conflict && address >= 0xFE00) {
        return wram[(address - 0xFE00) + 0x1E00];
    }

    else if ((address <= 0x7FFF) || BOUND(address, 0xA000, 0xBFFF)) {
        if (ioRegs.booting && (address <= 0x00FF)) {
            result = bootRom[address];
        } else {
            result = romRead(address);
        }
    } else if (BOUND(address, 0x8000, 0x9FFF)) {
        result = ppuReadByte(address, false);
    } else if (BOUND(address, 0xC000, 0xDFFF)) {
        result = wram[address - 0xC000];
    } else if (BOUND(address, 0xE000, 0xFDFF)) {
        result = wram[address - 0xE000];
    } else if (BOUND(address, 0xFE00, 0xFE9F)) {
        if (dma.active && conflict) {
            result = 0xFF;
        } else {
            result = ppuReadByte(address, true);
        }
    } else if (BOUND(address, 0xFF00, 0xFF7F)) {
        result = getIoReg(address & 0xFF);
    } else if (BOUND(address, 0xFF80, 0xFFFE)) {
        result = hram[address - 0xFF80];
    } else if (address == 0xFFFF) {
        result = ioRegs.IE;
    }

    busCycle(incr);
    return result;
}

void writeByte(uint16_t address, uint8_t data, bool incr) {
    if ((address <= 0x7FFF) || BOUND(address, 0xA000, 0xBFFF)) {
        romWrite(address, data);
    }

    else if (BOUND(address, 0x8000, 0x9FFF)) {
        ppuWriteByte(address, data, false);
    }

    else if (BOUND(address, 0xC000, 0xDFFF)) {
        wram[address - 0xC000] = data;
    } else if (BOUND(address, 0xE000, 0xFDFF)) {
        wram[address - 0xE000] = data;
    } else if (BOUND(address, 0xFE00, 0xFE9F)) {
        ppuWriteByte(address, data, true);
    }

    else if (BOUND(address, 0xFF00, 0xFF7F)) {
        setIoReg(address & 0xFF, data);
        if (address == 0xFF46) {
            dma.starting = true;
            dma.initialDelay = 2;
        }
    } else if (BOUND(address, 0xFF80, 0xFFFE)) {
        hram[address - 0xFF80] = data;
    } else if (address == 0xFFFF) {
        ioRegs.IE = data;
    }

    busCycle(incr);
}

void writeWord(uint16_t address, uint16_t data) {
    writeByte(address, LSB(data), true);
    writeByte(address + 1, MSB(data), true);
}

void internal() { busCycle(true); }

void dma_tick(DMA *d) {
    uint16_t addr = (uint16_t)ioRegs.DMA << 8;
    d->currentByte = readByte(addr + (uint16_t)d->currentIndex, false, false);
    ppuWriteByte(0xFE00 + (uint16_t)d->currentIndex, d->currentByte, true);
    d->currentIndex++;

    if (d->currentIndex == 0xA0) {
        d->active = false;
        d->initialDelay = 0;
        d->currentIndex = 0;
    }
}

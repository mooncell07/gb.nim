#include "io.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "joypad.h"
#include "logger.h"
#include "types.h"
#include "utils.h"

IORegisters ioRegs = {0};
#define IOREGBASE ((uint8_t *)&ioRegs)
#define IOREGLEN sizeof(IORegisters)

static inline uint8_t getRegisterAt(uint8_t address, long pageStart) {
    uint8_t *regAddr = (IOREGBASE + address + (uintptr_t)pageStart);
    if ((regAddr >= IOREGBASE) && (regAddr < (IOREGBASE + IOREGLEN))) {
        return *regAddr;
    } else {
        logState(FATAL,
                 "Attempted to READ from an invalid IO Register address.");
        return 0xFF;
    }
}

static inline void setRegisterAt(uint8_t address, long pageStart,
                                 uint8_t data) {
    uint8_t *regAddr = (IOREGBASE + address + (uintptr_t)pageStart);
    if ((regAddr >= IOREGBASE) && (regAddr < (IOREGBASE + IOREGLEN))) {
        *regAddr = data;
    } else {
        logState(FATAL,
                 "Attempted to WRITE to an invalid IO Register address.");
    }
}

uint8_t getIoReg(uint8_t address) {
    switch (address) {
        case 0x00:
            setKeyMask();
            if (js.fallingEdge) {
                sendIntReq(INTJOYPAD);
            }
            return js.keyMask;

        case 0x04:
            return MSB(ioRegs.DIV);

        case 0x0F:
            return ioRegs.IF;

        default:
            if (address >= 0x01 && address <= 0x07) {
                return getRegisterAt(address, offsetof(IORegisters, PAGE_0));
            } else if (address >= 0x40 && address <= 0x4B) {
                return getRegisterAt((address - 0x40) + 1,
                                     offsetof(IORegisters, PAGE_1));
            } else {
                return 0xFF;
            }
            break;
    }
}

void setIoReg(uint8_t address, uint8_t data) {
    switch (address) {
        case 0x00:
            js.P1 = data;
            break;

        case 0x04:
            ioRegs.DIV = 0;
            break;

        case 0x0F:
            ioRegs.IF = data;
            break;

        case 0x50:
            ioRegs.booting = false;
            break;

        default:
            if (address >= 0x01 && address <= 0x07) {
                setRegisterAt(address, offsetof(IORegisters, PAGE_0), data);
            } else if (address >= 0x40 && address <= 0x4B) {
                setRegisterAt((address - 0x40) + 1,
                              offsetof(IORegisters, PAGE_1), data);
            }
    }
}

bool getLCDC(LCDCType lct) { return BT(ioRegs.LCDC, lct); }

bool getLCDS(LCDSType lst) { return BT(ioRegs.STAT, lst); }

uint16_t getTileMapBase(bool win) {
    bool flag = win ? getLCDC(WINTILEMAPAREA) : getLCDC(BGTILEMAPAREA);
    return flag ? 0x9C00 : 0x9800;
}

uint16_t getTileDataBase(void) {
    return getLCDC(BGANDWINTILEDATAAREA) ? 0x8000 : 0x9000;
}

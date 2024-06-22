#include "timer.h"

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "io.h"
#include "ppu.h"
#include "types.h"
#include "utils.h"

static uint8_t CLKSEL[4] = {9, 3, 5, 7};

void timerTick() {
    uint16_t oldDIV = ioRegs.DIV;
    uint8_t freq = CLKSEL[ioRegs.TAC & 0x03];

    ioRegs.DIV++;

    if (BT(ioRegs.DIV, freq) && (!BT(oldDIV, freq)) && BT(ioRegs.TAC, 2)) {
        if (ioRegs.TIMA == 0xFF) {
            ioRegs.TIMA = ioRegs.TMA;
            sendIntReq(INTTIMER);
        }
        ioRegs.TIMA++;
    }
}

void incCycle(int m) {
    for (int i = 0; i < (m * 4); i++) {
        timerTick();
        ppuTick();
    }
}

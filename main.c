#include "cartridge.h"
#include "cpu.h"
#include "io.h"
#include "lcd.h"
#include "logger.h"
#include "mmu.h"
#include "ppu.h"
#include "timer.h"

void init(char path[]) {
    newRom(path);
    bool ok = initLCD();
    if (!ok) {
        freeMemory();
        exit(1);
    }
    ioRegs.booting = true;
    logState(INFO, "gb.c is ready.");
}

void step() {
    if (!halted) {
        cpuTick();
        //getSerialOutput();
    } else {
        incCycle(1);
    }

    checkPendingIRQs();
    if (IMERising) {
        IME = true;
    }
}

int main(int argc, char** argv) {
    if (argc > 0) {
        init(argv[1]);
    };
    while (RUNNING) {
        step();
    }
    logState(INFO, "bye");
    freeMemory();
    destroyLCD();
    return 0;
}

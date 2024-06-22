#pragma once
#include <stdbool.h>
#include <stdint.h>

void getSerialOutput();
void checkPendingIRQs();
void cpuTick();

extern uint8_t opcode;
extern bool halted;
extern bool IME;
extern bool IMERising;

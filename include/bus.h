#pragma once
#include <stdbool.h>
#include <stdint.h>

uint8_t readByte(uint16_t address, bool incr, bool conflict);
void writeByte(uint16_t address, uint8_t data, bool incr);
void writeWord(uint16_t address, uint16_t data);
void internal();

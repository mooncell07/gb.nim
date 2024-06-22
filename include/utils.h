#pragma once
#include <stdbool.h>
#include <stdint.h>

#include "types.h"

#define LSB(v) (v & 0xFF)
#define MSB(v) (v >> 8)
#define JOIN(hi, lo) ((hi << 8) | lo)
#define BT(v, pos) (v & (1 << pos) ? true : false)

#define setBit(v, pos) (v |= (1 << pos))
#define clearBit(v, pos) (v &= ~(1 << pos))

#define checkHalfCarry(a, b) ((a & 0xF) + (b & 0xF) >= 0x10)
#define checkHalfBorrow(a, b) ((a & 0xF) < (b & 0xF))

static inline uint8_t rotateLeftBits(uint8_t value, int count) {
    return (value << count) | (value >> (8 - count));
}

static inline uint8_t rotateRightBits(uint8_t value, int count) {
    return (value >> count) | (value << (8 - count));
}

static inline uint8_t BEXTR(uint8_t v, int start, int end) {
    uint8_t len = (end - start + 1);
    return (v >> start) & ((1 << len) - 1);
}

#define xMask(opcode) BEXTR(opcode, 6, 7)
#define yMask(opcode) BEXTR(opcode, 3, 5)
#define zMask(opcode) BEXTR(opcode, 0, 2)
#define pMask(opcode) BEXTR(opcode, 4, 5)
#define qMask(opcode) BT(opcode, 3)

#define BOUND(address, lower, upper) (lower <= address && address <= upper)

static inline R16Type group2adjust(uint8_t reg) {
    return (reg == 3) ? AF : (R16Type)reg;
}

#pragma once

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

#include "bus.h"
#include "types.h"
#include "utils.h"

uint8_t r8[8];
uint16_t pc;
uint16_t sp;
uint8_t flag;

static inline uint16_t getReg16(R16Type r) {
    switch (r) {
        case BC:
            return JOIN(r8[B], r8[C]);
        case DE:
            return JOIN(r8[D], r8[E]);
        case HL:
            return JOIN(r8[H], r8[L]);
        case SP:
            return sp;
        case AF:
            return JOIN(r8[A], flag);
        default:
            return 0xFF;
    }
}

static inline uint8_t getReg8(R8Type r) {
    if (r == aHL) {
        return readByte(getReg16(HL), true, true);
    }
    return r8[r];
}

static inline void setReg8(R8Type r, uint8_t n) {
    if (r == aHL) {
        writeByte(getReg16(HL), n, true);
    } else {
        r8[r] = n;
    }
}

static inline void setReg16(R16Type r, uint16_t n) {
    switch (r) {
        case BC:
            r8[B] = MSB(n);
            r8[C] = LSB(n);
            break;
        case DE:
            r8[D] = MSB(n);
            r8[E] = LSB(n);
            break;
        case HL:
            r8[H] = MSB(n);
            r8[L] = LSB(n);
            break;
        case SP:
            sp = n;
            break;
        case AF:
            r8[A] = MSB(n);
            flag = n & 0xFFF0;
            break;
        default:
            break;
    }
}

static inline bool getFlag(FlagType ft) { return BT(flag, ft); }

static inline void setFlag(FlagType ft, bool v) {
    if (v) {
        setBit(flag, ft);
    } else {
        clearBit(flag, ft);
    }
}

#define setZ(v) setFlag(ftZ, v)
#define setN(v) setFlag(ftN, v)
#define setH(v) setFlag(ftH, v)
#define setC(v) setFlag(ftC, v)

static inline bool getCC(CCType cc) {
    switch (cc) {
        case ccNZ:
            return !getFlag(ftZ);
            break;
        case ccZ:
            return getFlag(ftZ);
            break;
        case ccNC:
            return !getFlag(ftC);
            break;
        case ccC:
            return getFlag(ftC);
            break;
    }
    return false;
}

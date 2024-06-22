#include "cpu.h"

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "bus.h"
#include "io.h"
#include "logger.h"
#include "registers.h"
#include "types.h"

uint8_t opcode = 0x00;
bool halted = false;
bool IME = false;
bool IMERising = false;

void getSerialOutput() {
    if (readByte(0xFF02, false, true) == 0x81) {
        printf("%c", (char)readByte(0xFF01, false, true));
        writeByte(0xFF02, 0, false);
    }
}

void reportInvalidOpcode() {
    // Leaving P and Q masks because they are always fully covered by the
    // switch/if statements.
    char msg[80];
    snprintf(msg, sizeof(msg), "Invalid Opcode: $%X @ (X:%d Z:%d Y:%d) ",
             opcode, xMask(opcode), zMask(opcode), yMask(opcode));
    logState(FATAL, msg);
}

uint8_t fetch() {
    uint8_t res = readByte(pc, true, true);
    pc++;
    return res;
}
uint16_t fetchWord() {
    uint8_t lo = fetch();
    uint8_t hi = fetch();
    return JOIN(hi, lo);
}

uint16_t pop() {
    uint8_t lo = readByte(sp, true, true);
    sp++;
    uint8_t hi = readByte(sp, true, true);
    sp++;
    return JOIN(hi, lo);
}

void push(uint16_t data) {
    sp--;
    writeByte(sp, MSB(data), true);
    sp--;
    writeByte(sp, LSB(data), true);
}

void jump(uint16_t address, bool internalCycle) {
    if (internalCycle) {
        internal();
    }

    push(pc);
    pc = address;
}

void opLDr_r(R8Type src, R8Type dest) { setReg8(src, getReg8(dest)); }

void opLDr_n(R8Type reg) { setReg8(reg, fetch()); }

void opLDr_nn(R16Type reg) { setReg16(reg, fetchWord()); }

void opLDr_addr(R8Type reg, uint16_t address) {
    setReg8(reg, readByte(address, true, true));
}

void opLDaddr_r(uint16_t address, R8Type reg) {
    writeByte(address, getReg8(reg), true);
}

void opLDRP_word(R16Type reg, uint16_t data) {
    setReg16(reg, data);
    internal();
}

void opLDaddr_SP() {
    uint16_t nn = fetchWord();
    writeByte(nn, LSB(sp), true);
    writeByte(nn + 1, MSB(sp), true);
}

void opPUSHR16(R16Type reg, bool internalCycles) {
    if (internalCycles) {
        internal();
    }

    push(getReg16(reg));
}

void opPUSHDATA(uint16_t data, bool internalCycles) {
    if (internalCycles) {
        internal();
    }
    push(data);
}

void opPOP(R16Type reg) { setReg16(reg, pop()); }

void opCALL(uint16_t address, bool internalCycles) {
    jump(address, internalCycles);
}

void opJP(uint16_t address, bool hl) {
    pc = address;
    if (!hl) {
        internal();
    }
}

void opJR() {
    int8_t offset = (int8_t)fetch();
    pc += offset;
    internal();
}

void opJRcond(CCType cond) {
    int8_t offset = ((int8_t)fetch());
    if (getCC(cond)) {
        pc += (uint16_t)offset;
        internal();
    }
}

void opRET(uint16_t address) {
    pc = address;
    internal();
}

void opRETcond(CCType cond) {
    if (getCC(cond)) {
        pc = pop();
        internal();
    }
    internal();
}

void opRETI() {
    IME = true;
    opRET(pop());
}

void opSTOP() {
    pc++;
    halted = true;
}

void alu(AluOp op, uint8_t data) {
    uint8_t acc = getReg8(A);
    uint8_t res = 0;

    switch (op) {
        case OR:
            res = acc | data;
            setN(false);
            setH(false);
            setC(false);
            break;

        case CP:
            res = acc - data;
            setN(true);
            setH(checkHalfBorrow(acc, data));
            setC(data > acc);
            break;

        case AND:
            res = acc & data;
            setN(false);
            setH(true);
            setC(false);
            break;

        case XOR:
            res = acc ^ data;
            setN(false);
            setH(false);
            setC(false);
            break;

        case ADD:
            res = acc + data;
            setN(false);
            setH(checkHalfCarry(acc, data));
            setC(acc > res);
            break;

        case SUB:
            res = acc - data;
            setN(true);
            setH(checkHalfBorrow(acc, data));
            setC(data > acc);
            break;

        case ADC:
            res = acc + data + (uint8_t)getFlag(ftC);
            setN(false);
            setH(((acc & 0xF) + (data & 0xF) + (uint8_t)getFlag(ftC)) > 0xF);
            setC(((uint16_t)acc + (uint16_t)data + (uint16_t)getFlag(ftC)) >
                 0xFF);
            break;

        case SBC:
            res = acc - (uint8_t)getFlag(ftC) - data;
            setN(true);
            setH(((data & 0xF) + (uint8_t)getFlag(ftC)) > (acc & 0xF));
            setC(((uint16_t)data + (uint8_t)getFlag(ftC)) > acc);
            break;
    }

    setZ(res == 0);

    if (op != CP) {
        setReg8(A, res);
    }
}

void opINC8(R8Type reg) {
    uint8_t value = getReg8(reg);
    uint8_t res = value + 1;
    setZ(res == 0);
    setN(false);
    setH(checkHalfCarry(value, 1));
    setReg8(reg, res);
}

void opINC16(R16Type reg) {
    uint16_t value = getReg16(reg);
    uint16_t res = value + 1;
    internal();
    setReg16(reg, res);
}

void opDEC8(R8Type reg) {
    uint8_t value = getReg8(reg);
    uint8_t res = value - 1;
    setZ(res == 0);
    setN(true);
    setH(checkHalfBorrow(value, 1));
    setReg8(reg, res);
}

void opDEC16(R16Type reg) {
    uint16_t value = getReg16(reg);
    uint16_t res = value - 1;
    internal();
    setReg16(reg, res);
}

void opADDHL_RP(R16Type reg) {
    uint16_t hl = getReg16(HL);
    uint16_t data = getReg16(reg);

    setReg16(HL, hl + data);
    setN(false);
    setH((hl & 0xFFF) + (data & 0xFFF) > 0xFFF);
    setC(((uint32_t)hl + (uint32_t)data) > 0xFFFF);

    internal();
}

void opADDSP_i8(bool internals) {
    uint16_t data = (uint16_t)((int8_t)fetch());
    uint16_t res = sp + data;

    setZ(false);
    setN(false);
    setH((sp & 0xF) + (data & 0xF) > 0xF);
    setC((sp & 0xFF) + (data & 0xFF) > 0xFF);

    if (internals) {
        internal();
        internal();
    }
    sp = res;
}

void prefixHandler() {
    uint8_t op = fetch();
    R8Type reg = (R8Type)(zMask(op));

    uint8_t res = 0;

    switch (xMask(op)) {
        case 0x0:
            PrefixOp rot = (PrefixOp)(yMask(op));
            uint8_t u8 = getReg8(reg);

            switch (rot) {
                case RL:
                    res = (u8 << 1) | getFlag(ftC);
                    setC((u8 >> 7) != 0);
                    break;

                case RR:
                    res = (u8 >> 1) | (getFlag(ftC) << 7);
                    setC((u8 & 1) == 1);
                    break;

                case RLC:
                    setC((u8 >> 7) != 0);
                    res = rotateLeftBits(u8, 1) | getFlag(ftC);
                    break;
                case RRC:
                    setC((u8 & 1) == 1);
                    res = rotateRightBits(u8, 1) | (0x80 & getFlag(ftC));
                    break;
                case SLA:
                    res = u8 << 1;
                    setC((u8 >> 7) != 0);
                    break;
                case SRL:
                    res = u8 >> 1;
                    setC((u8 & 1) == 1);
                    break;
                case SRA:
                    res = (u8 >> 1) | (u8 & 0x80);
                    setC((u8 & 1) == 1);
                    break;
                case SWAP:
                    res = rotateLeftBits(u8, 4);
                    setC(false);
                    break;
            }
            break;

        case 0x1:
            uint8_t val = getReg8(reg);
            setZ(!BT(val, yMask(op)));
            setN(false);
            setH(true);
            break;
        case 0x2:
            res = getReg8(reg);
            clearBit(res, yMask(op));
            break;
        case 0x3:
            res = getReg8(reg);
            setBit(res, yMask(op));

            break;
        default:
            break;
    }

    if (xMask(op) != 1) {
        setReg8(reg, res);
        if (xMask(op) == 0) {
            setZ(res == 0);
            setN(false);
            setH(false);
        }
    }
}

void opDAA() {
    uint8_t value = getReg8(A);
    if (!getFlag(ftN)) {
        if (getFlag(ftH) | ((getReg8(A) & 0x0F) > 9)) {
            value += 6;
        }

        if (getFlag(ftC) | (getReg8(A) > 0x99)) {
            value += 0x60;
            setC(true);
        }
    } else {
        if (getFlag(ftC)) {
            value -= 0x60;
        }

        if (getFlag(ftH)) {
            value -= 6;
        }
    }
    setZ(value == 0);
    setH(false);
    setReg8(A, value);
}

void opRLA() {
    uint8_t acc = getReg8(A);
    uint8_t data = (acc << 1) | (getFlag(ftC) ? 1 : 0);

    setC((acc >> 7) != 0);
    setZ(false);
    setN(false);
    setH(false);
    setReg8(A, data);
}

void opRLCA() {
    uint8_t acc = getReg8(A);
    setC((acc >> 7) != 0);
    uint8_t data = rotateLeftBits(acc, 1) | (getFlag(ftC) ? 1 : 0);
    setZ(false);
    setN(false);
    setH(false);
    setReg8(A, data);
}

void opRRA() {
    uint8_t u8 = getReg8(A);
    uint8_t res = (u8 >> 1) | (getFlag(ftC) << 7);
    setZ(false);
    setN(false);
    setH(false);
    setC((u8 & 1) == 1);
    setReg8(A, res);
}

void opRRCA() {
    uint8_t acc = getReg8(A);
    setC((acc & 1) == 1);
    uint8_t data = rotateRightBits(acc, 1) | (0x80 & (getFlag(ftC) ? 1 : 0));
    setZ(false);
    setN(false);
    setH(false);
    setReg8(A, data);
}

void cpuTick() {
    opcode = fetch();
    if (opcode == 0xCB) {
        prefixHandler();
        return;
    }

    switch (xMask(opcode)) {
        case 0x0:
            switch (zMask(opcode)) {
                case 0x0:

                    switch (yMask(opcode)) {
                        case 0x0:
                            break;
                        case 0x1:
                            opLDaddr_SP();
                            break;
                        case 0x2:
                            opSTOP();
                            break;
                        case 0x3:
                            opJR();
                            break;
                        case 0x4:
                        case 0x5:
                        case 0x6:
                        case 0x7:
                            opJRcond((CCType)(yMask(opcode) - 4));
                            break;
                        default:
                            reportInvalidOpcode();
                            break;
                    }

                    break;

                case 0x1:
                    if (!qMask(opcode)) {
                        opLDr_nn((R16Type)pMask(opcode));
                    } else {
                        opADDHL_RP((R16Type)pMask(opcode));
                    }

                    break;

                case 0x2:
                    if (!qMask(opcode)) {
                        switch (pMask(opcode)) {
                            case 0x0:
                                opLDaddr_r(getReg16(BC), A);
                                break;
                            case 0x1:
                                opLDaddr_r(getReg16(DE), A);
                                break;
                            case 0x2: {
                                uint16_t data = getReg16(HL);
                                opLDaddr_r(data, A);
                                setReg16(HL, data + 1);
                                break;
                            }
                            case 0x3: {
                                uint16_t data = getReg16(HL);
                                opLDaddr_r(data, A);
                                setReg16(HL, data - 1);
                                break;
                            }
                        }
                    } else {
                        switch (pMask(opcode)) {
                            case 0x0:
                                opLDr_addr(A, getReg16(BC));
                                break;
                            case 0x1:
                                opLDr_addr(A, getReg16(DE));
                                break;
                            case 0x2:
                                uint16_t d = getReg16(HL);
                                opLDr_addr(A, d);
                                setReg16(HL, d + 1);
                                break;
                            case 0x3:
                                uint16_t ata = getReg16(HL);
                                opLDr_addr(A, ata);
                                setReg16(HL, ata - 1);
                                break;
                        }
                    }

                    break;

                case 0x3:
                    if (!qMask(opcode)) {
                        opINC16((R16Type)pMask(opcode));
                    } else {
                        opDEC16((R16Type)pMask(opcode));
                    }

                    break;

                case 0x4:
                    opINC8((R8Type)(yMask(opcode)));
                    break;
                case 0x5:
                    opDEC8((R8Type)(yMask(opcode)));
                    break;
                case 0x6:
                    opLDr_n((R8Type)(yMask(opcode)));
                    break;
                case 0x7:
                    switch (yMask(opcode)) {
                        case 0x0:
                            opRLCA();
                            break;
                        case 0x1:
                            opRRCA();
                            break;
                        case 0x2:
                            opRLA();
                            break;
                        case 0x3:
                            opRRA();
                            break;
                        case 0x4:
                            opDAA();
                            break;
                        case 0x5:
                            setReg8(A, ~getReg8(A));
                            setN(true);
                            setH(true);
                            break;
                        case 0x6:
                            setC(true);
                            setN(false);
                            setH(false);
                            break;
                        case 0x7:
                            setC(!getFlag(ftC));
                            setN(false);
                            setH(false);
                            break;
                        default:
                            reportInvalidOpcode();
                            break;
                    }
                    break;
                default:
                    reportInvalidOpcode();
                    break;
            }
            break;

        case 0x1:
            if ((zMask(opcode) == 0x6) && (yMask(opcode) == 0x6)) {
                halted = true;
            } else {
                opLDr_r((R8Type)yMask(opcode), (R8Type)zMask(opcode));
            }
            break;

        case 0x2:
            alu((AluOp)(yMask(opcode)), getReg8((R8Type)zMask(opcode)));
            break;

        case 0x3:
            switch (zMask(opcode)) {
                case 0x0:
                    switch (yMask(opcode)) {
                        case 0x0:
                        case 0x1:
                        case 0x2:
                        case 0x3:
                            opRETcond((CCType)yMask(opcode));
                            break;
                        case 0x4:
                            opLDaddr_r(0xFF00 + fetch(), A);
                            break;
                        case 0x5:
                            opADDSP_i8(true);
                            break;
                        case 0x6:
                            opLDr_addr(A, 0xFF00 + fetch());
                            break;
                        case 0x7: {
                            uint16_t old_sp = sp;
                            opADDSP_i8(false);
                            opLDRP_word(HL, sp);
                            sp = old_sp;
                            break;
                        }
                    }
                    break;
                case 0x1:
                    if (!qMask(opcode)) {
                        opPOP(group2adjust(pMask(opcode)));
                    } else {
                        switch (pMask(opcode)) {
                            case 0x0:
                                opRET(pop());
                                break;
                            case 0x1:
                                opRETI();
                                break;
                            case 0x2:
                                opJP(getReg16(HL), true);
                                break;
                            case 0x3:
                                opLDRP_word(SP, getReg16(HL));
                                break;
                        }
                    }
                    break;

                case 0x2:
                    switch (yMask(opcode)) {
                        case 0x0:
                        case 0x1:
                        case 0x2:
                        case 0x3: {
                            uint16_t nn = fetchWord();
                            if (getCC((CCType)yMask(opcode))) {
                                opJP(nn, false);
                            }
                            break;
                        }
                        case 0x4:
                            opLDaddr_r(0xFF00 + getReg8(C), A);
                            break;
                        case 0x5:
                            opLDaddr_r(fetchWord(), A);
                            break;
                        case 0x6:
                            opLDr_addr(A, 0xFF00 + getReg8(C));
                            break;
                        case 0x7:
                            opLDr_addr(A, fetchWord());
                            break;
                    }
                    break;

                case 0x3:
                    switch (yMask(opcode)) {
                        case 0x0:
                            opJP(fetchWord(), false);
                            break;
                        case 0x6:
                            IME = false;
                            break;
                        case 0x7:
                            IMERising = true;
                            break;
                        default:
                            reportInvalidOpcode();
                            break;
                    }
                    break;

                case 0x4: {
                    uint16_t nn = fetchWord();
                    if (getCC((CCType)yMask(opcode))) {
                        opCALL(nn, true);
                    }
                    break;
                }
                case 0x5:
                    if (!qMask(opcode)) {
                        opPUSHR16(group2adjust(pMask(opcode)), true);
                    } else {
                        if (pMask(opcode) == 0) {
                            opCALL(fetchWord(), true);
                        } else {
                            reportInvalidOpcode();
                        }
                    }
                    break;
                case 0x6:
                    alu((AluOp)yMask(opcode), fetch());
                    break;
                case 0x7:
                    opCALL(yMask(opcode) * 8, true);
                    break;
            }
            break;

        default:
            reportInvalidOpcode();
            break;
    }
}

const uint16_t IVT[5] = {0x40, 0x48, 0x50, 0x58, 0x60};

void serviceIRQ(IntType intT) {
    halted = false;
    IME = false;
    IMERising = false;
    clearBit(ioRegs.IF, intT);
    jump(IVT[intT], false);
}

void handlePendingIRQs() {
    for (int i = 0; i < 5; i++) {
        if (BT(ioRegs.IF, i) & BT(ioRegs.IE, i)) {
            serviceIRQ((IntType)i);
        }
    }
}

void checkPendingIRQs() {
    if (ioRegs.IF == 0) {
        return;
    }
    halted = false;
    if (IME) {
        handlePendingIRQs();
    }
}

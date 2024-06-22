#pragma once
#include <stdbool.h>
#include <stdint.h>

#include "types.h"
#include "utils.h"

typedef struct {
    // Memory Mapped Registers, divided into 2 pages, the order is important.

    // Page 0 Registers from 0xFF01 to 0xFF07 [Serial IO & Timer]
    uint8_t PAGE_0;  // PAGE 0 START
    uint8_t SB;      // 0x01
    uint8_t SC;      // 0x02
    uint16_t DIV;    // 0x04
    uint8_t TIMA;    // 0x05
    uint8_t TMA;     // 0x06
    uint8_t TAC;     // 0x07

    // Page 1 Registers from 0xFF40 to 0xFF4B [PPU]
    uint8_t PAGE_1;  // PAGE 1 START
    uint8_t LCDC;    // 0x40
    uint8_t STAT;    // 0x41
    uint8_t SCY;     // 0x42
    uint8_t SCX;     // 0x43
    uint8_t LY;      // 0x44
    uint8_t LYC;     // 0x45
    uint8_t DMA;     // 0x46
    uint8_t BGP;     // 0x47
    uint8_t OBP0;    // 0x48
    uint8_t OBP1;    // 0x49
    uint8_t WY;      // 0x4A
    uint8_t WX;      // 0x4B

    // Unmapped Internal Registers
    uint8_t LX;
    uint8_t WLY;

    // Unreadable Register
    bool booting;  // 0x50

    // Interrupt Registers
    uint8_t IF;  // 0x0F
    uint8_t IE;  // 0xFF

} IORegisters;

extern IORegisters ioRegs;

static inline void sendIntReq(IntType ISR) { setBit(ioRegs.IF, ISR); }

uint8_t getIoReg(uint8_t address);
void setIoReg(uint8_t address, uint8_t data);
bool getLCDC(LCDCType lct);
bool getLCDS(LCDSType lst);
uint16_t getTileMapBase(bool win);
uint16_t getTileDataBase(void);

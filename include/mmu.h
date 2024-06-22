#pragma once
#include <stdbool.h>
#include <stdint.h>

extern uint8_t wram[0x2000];
extern uint8_t hram[0x80];

extern uint8_t *bootRom;
extern uint8_t *romData;
extern uint8_t *extRam;
extern uint8_t ramSizeCode;
extern uint8_t romBankCount;
extern bool extRamFlag;

typedef struct {
    uint8_t romBank;
    uint8_t ramBank;
    bool modeFlag;
} MBC1;

bool buildExternalMemory();
uint8_t readRom(MBC1 *mapper, uint16_t address);
void intercept(MBC1 *mapper, uint16_t address, uint8_t data);

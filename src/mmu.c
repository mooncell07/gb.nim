#include "mmu.h"

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "utils.h"

const int RAMBANKS[6] = {0, 1, 2, 4, 16, 8};

uint8_t wram[0x2000];
uint8_t hram[0x80];

uint8_t *bootRom;
uint8_t *romData;
uint8_t *extRam;
uint8_t ramSizeCode;
uint8_t romBankCount;
bool extRamFlag;

bool buildExternalMemory() {
    int totalSize = RAMBANKS[ramSizeCode] * 0x2000;
    extRam = (uint8_t *)malloc(totalSize * sizeof(uint8_t));
    return extRam != NULL;
}

uint8_t readRom(MBC1 *mapper, uint16_t address) {
    if (address <= 0x3FFF) {
        return romData[address];
    }

    else if (BOUND(address, 0x4000, 0x7FFF)) {
        uint16_t highBankNum = mapper->romBank & (romBankCount - 1);
        uint32_t addr = 0x4000 * highBankNum + (address - 0x4000);
        return romData[addr];
    }

    else if (BOUND(address, 0xA000, 0xBFFF)) {
        if (extRamFlag) {
            if ((ramSizeCode > 0x02) && mapper->modeFlag) {
                return extRam[0x2000 * mapper->ramBank + (address - 0xA000)];
            } else {
                return extRam[(address - 0xA000)];
            }
        } else {
            return 0xFF;
        }
    } else {
        return 0xFF;
    }
}

void intercept(MBC1 *mapper, uint16_t address, uint8_t data) {
    if (address <= 0x1FFF) {
        extRamFlag = BEXTR(data, 0, 3) == 0xA;
    } else if (BOUND(address, 0x2000, 0x3FFF)) {
        uint8_t maskedData = data & 0x1F;
        mapper->romBank = maskedData % romBankCount;
        if ((mapper->romBank == 0) && (maskedData < romBankCount)) {
            mapper->romBank = 1;
        }
    } else if (BOUND(address, 0x4000, 0x5FFF)) {
        mapper->ramBank = BEXTR(data, 0, 1);
    } else if (BOUND(address, 0x6000, 0x7FFF)) {
        mapper->modeFlag = BT(data, 0);
    } else if (BOUND(address, 0xA000, 0xBFFF)) {
        if (extRamFlag) {
            if ((ramSizeCode > 0x02) && mapper->modeFlag) {
                extRam[0x2000 * mapper->ramBank + (address - 0xA000)] = data;
            } else {
                extRam[(address - 0xA000)] = data;
            }
        }
    }
}

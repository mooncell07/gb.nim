
#include "cartridge.h"

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "logger.h"
#include "mmu.h"
#include "types.h"
#include "utils.h"

MBC1 mbc1 = {1, 1, false};
CartridgeHeaders cartHeaders = {0};

void freeMemory() {
    if (romData != NULL) {
        free(romData);
        romData = NULL;
    }

    if (bootRom != NULL) {
        free(bootRom);
        bootRom = NULL;
    }

    if (extRam != NULL) {
        free(extRam);
        extRam = NULL;
    }
}

void fileError(char msg[]) {
    logState(FATAL, msg);
    // At this point in time only the romData and bootRom are allocated.
    freeMemory();
    exit(1);
}

void readBinary(char filepath[], uint8_t **buffer) {
    FILE *file = fopen(filepath, "rb");

    if (!file) {
        fileError("Failed to open file.");
    }

    fseek(file, 0, SEEK_END);
    size_t fileSize = ftell(file);
    rewind(file);
    *buffer = (uint8_t *)malloc(fileSize);

    if (!*buffer) {
        fileError("Failed to allocate memory for file.");
    }
    size_t actualSize = fread(*buffer, 1, fileSize, file);

    if (actualSize != fileSize) {
        fileError("Failed to read file.");
    }

    fclose(file);
}

uint8_t romRead(uint16_t address) { return readRom(&mbc1, address); }

void romWrite(uint16_t address, uint8_t data) {
    intercept(&mbc1, address, data);
}

void parseHeaders() {
    // NOT IMPLEMENTED
}

void runChecksum() {
    uint8_t checksum = 0;

    for (int i = 0x0134; i <= 0x014C; i++) {
        checksum = checksum - romData[i] - 1;
    }

    if ((LSB(checksum)) == romData[0x014D]) {
        cartHeaders.checksum = checksum;
        logState(INFO, "Checksum Passed.");
    } else {
        logState(FATAL, "Checksum Failed.");
    }
}

void newRom(char filepath[]) {
    logState(INFO, "Loading ROM...");
    readBinary(filepath, &romData);

    logState(INFO, "Loading Boot ROM...");
    readBinary("../roms/bootrom.gb", &bootRom);

    runChecksum();
    parseHeaders();

    int romSize = 32 << (int)romData[0x0148];
    romBankCount = (uint8_t)(romSize / 16);
    ramSizeCode = romData[0x0149];
    bool ok = buildExternalMemory();
    if (!ok) {
        logState(FATAL, "Failed to allocate memory for external RAM.");
        freeMemory();
        exit(1);
    }
}

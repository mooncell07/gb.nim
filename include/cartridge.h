#pragma once
#include <stdint.h>

typedef struct {
    char title[60];
    char licensee[60];
    char romType[60];
    int romSize;
    uint8_t romVer;
    uint8_t destinationCode;
    uint8_t checksum;
} CartridgeHeaders;

uint8_t romRead(uint16_t address);
void romWrite(uint16_t address, uint8_t data);
void newRom(char filepath[]);
void freeMemory();

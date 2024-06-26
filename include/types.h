#pragma once

#define BUILDTYPE(name, ...) typedef enum { __VA_ARGS__ } name

BUILDTYPE(R8Type, B, C, D, E, H, L, aHL, A);
BUILDTYPE(R16Type, BC, DE, HL, SP, AF);
BUILDTYPE(PrefixOp, RLC, RRC, RL, RR, SLA, SRA, SWAP, SRL);
BUILDTYPE(CCType, ccNZ, ccZ, ccNC, ccC);
BUILDTYPE(FlagType, ftC = 4, ftH = 5, ftN = 6, ftZ = 7);
BUILDTYPE(IntType, INTVBLANK, INTSTAT, INTTIMER, INTSERIAL, INTJOYPAD);
BUILDTYPE(AluOp, ADD, ADC, SUB, SBC, AND, XOR, OR, CP);
BUILDTYPE(PPUStateType, HBLANK, VBLANK, OAMSEARCH, PIXELTRANSFER);
BUILDTYPE(LCDCType, BGANDWINEN, OBJEN, OBJSIZE, BGTILEMAPAREA,
          BGANDWINTILEDATAAREA, WINEN, WINTILEMAPAREA, LCDPPUEN);
BUILDTYPE(LCDSType, PPUMODEBIT0, PPUMODEBIT1, COINCIDENCE, MODE0INT, MODE1INT,
          MODE2INT, LYCINT);
BUILDTYPE(LogLevel, INFO, DEBUG, WARN, FATAL);

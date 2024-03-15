import bitops

import utils
import types


var
    # Serial Data Buffer
    SB: uint8 = 0x00
    SC: uint8 = 0x7E

    # Interrupt Registers
    IF*: uint8 = 0xE1
    IE*: uint8 = 0x00

    # Timer Registers
    DIV*: uint16 = 0xAB
    TIMA*: uint8 = 0x00
    TMA*: uint8 = 0x00
    TAC*: uint8 = 0xF8

    # PPU Registers
    LCDC*: uint8 = 0x91
    STAT*: uint8 = 0x85

    SCY*: uint8 = 0x00
    SCX*: uint8 = 0x00
    LY*: uint8 = 0x00
    LYC*: uint8 = 0x00
    DMA*: uint8 = 0xFF
    BGP*: uint8 = 0xFC
    OBP0*: uint8 = 0x00
    OBP1*: uint8 = 0x00
    WY*: uint8 = 0x00
    WX*: uint8 = 0x00


# LUT to avoid condition chaining :/
var
    SerialRegTable: array[2, ptr uint8] = [addr SB, addr SC]
    TimerRegTable: array[3, ptr uint8] = [addr TIMA, addr TMA, addr TAC]
    PPURegTable: array[12, ptr uint8] = [addr LCDC, addr STAT, addr SCY,
            addr SCX, addr LY, addr LYC, addr DMA, addr BGP, addr OBP0,
            addr OBP1,
            addr WY, addr WX]

proc getIoReg*(address: int): uint8 =
    if address.isboundto(0x01, 0x02):
        result = SerialRegTable[address - 1][]

    elif address == 0x0F: result = IF
    elif address == 0x04: result = msb(DIV)

    elif address.isboundto(0x05, 0x07):
        result = TimerRegTable[address - 5][]

    elif address.isboundto(0x40, 0x4B):
        result = PPURegTable[address and 0xF][]

proc setIoReg*(address: int, data: uint8): void =
    if address.isboundto(0x01, 0x02):
        SerialRegTable[address - 1][] = data

    elif address == 0x0F: IF = data
    elif address == 0x04: DIV = 0

    elif address.isboundto(0x05, 0x07):
        TimerRegTable[address - 5][] = data

    elif address.isboundto(0x40, 0x4B):
        PPURegTable[address and 0xF][] = data

proc sendIntReq*(ISR: IntType): void =
    setBit(IF, ISR.ord)


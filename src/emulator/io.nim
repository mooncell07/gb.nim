import bitops

import utils
import types

var
    # Serial Data Buffer
    serialData: array[2, uint8]

    # Interrupt Registers
    IE*: uint8 = 0x00
    IF*: uint8 = 0xE1

    # Timer Registers
    DIV*: uint16 = 0x18
    TIMA*: uint8 = 0x00
    TMA*: uint8 = 0x00
    TAC*: uint8 = 0xF8


proc sendIntReq*(ISR: IntType): void =
    setBit(IF, ISR.ord)

proc setTimerReg(reg: u2, data: uint8): void =
    case reg
    of 0: DIV = 0
    of 1: TIMA = data
    of 2: TMA = data
    of 3: TAC = data

proc getTimerReg(reg: u2): uint8 =
    case reg
    of 0: msb(DIV)
    of 1: TIMA
    of 2: TMA
    of 3: TAC

proc ioReadByte*(address: uint16): uint8 =
    if address == 0xFF01: result = serialData[0]
    elif address == 0xFF02: result = serialData[1]
    elif address == 0xFF0F: result = IF
    elif address.isboundto(0xFF04, 0xFF07):
        result = getTimerReg(((address and 0xF) - 4).u2)
    elif address.isboundto(0xFF40, 0xFF4B):
        result = 0x90

proc ioWriteByte*(address: uint16, data: uint8): void =
    if address == 0xFF01: serialData[0] = data
    elif address == 0xFF02: serialData[1] = data
    elif address == 0xFF0F: IF = data
    elif address.isboundto(0xFF04, 0xFF07):
        setTimerReg(((address and 0xF) - 4).u2, data)

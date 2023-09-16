import utils
import bitops
import types

var 
    # Serial Data Buffer
    serialData: array[2, uint8]

    # Interrupt Registers
    IE*: uint8
    IF*: uint8

    # Timer Registers
    DIV*: uint16 = 0xAC00
    TIMA*: uint8
    TMA*: uint8
    TAC*: uint8

proc sendIntReq*(ISR: IntType): void {.inline.} =
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
    if address == 0xFF01'u16: result = serialData[0]
    elif address == 0xFF02'u16: result = serialData[1]
    elif address == 0xFF0F'u16: result = IF
    elif address.isboundto(0xFF04'u16, 0xFF07'u16):
        result = getTimerReg(((address and 0xF) - 4).u2)
    elif address.isboundto(0xFF40'u16, 0xFF4B'u16):
        result = 0x90'u8

proc ioWriteByte*(address: uint16, data: uint8): void =
    if address == 0xFF01'u16: serialData[0] = data
    elif address == 0xFF02'u16: serialData[1] = data
    elif address == 0xFF0F'u16: IF = data
    elif address.isboundto(0xFF04'u16, 0xFF07'u16):
        setTimerReg(((address and 0xF) - 4).u2, data)

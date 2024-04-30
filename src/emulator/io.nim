import bitops
import utils
import types

var
    # Serial Data Buffer
    SB: uint8
    SC: uint8

    # Interrupt Registers
    IF*: uint8
    IE*: uint8

    # Timer Registers
    DIV*: uint16
    TIMA*: uint8
    TMA*: uint8
    TAC*: uint8

    # PPU Registers
    LCDC*: uint8
    STAT*: uint8
    SCY*: uint8
    SCX*: uint8
    LY*: uint8
    LYC*: uint8
    DMA*: uint8
    BGP*: uint8
    OBP0*: uint8
    OBP1*: uint8
    WY*: uint8
    WX*: uint8

    # PPU Internal Registers
    LX*: uint8
    WLY*: uint8

    booting*: bool = true

var
    serialRegTable: array[2, ptr uint8] = [addr SB, addr SC]
    timerRegTable: array[3, ptr uint8] = [addr TIMA, addr TMA, addr TAC]
    ppuRegTable: array[12, ptr uint8] = [addr LCDC, addr STAT, addr SCY,
            addr SCX, addr LY, addr LYC, addr DMA, addr BGP, addr OBP0,
            addr OBP1,
            addr WY, addr WX]

proc getIoReg*(address: int): uint8 =
    if address.isboundto(0x01, 0x02):
        result = serialRegTable[address - 1][]

    elif address == 0x0F: result = IF
    elif address == 0x04: result = msb(DIV)

    elif address.isboundto(0x05, 0x07):
        result = timerRegTable[address - 5][]

    elif address.isboundto(0x40, 0x4B):
        result = ppuRegTable[address and 0xF][]

proc setIoReg*(address: int, data: uint8): void =
    if address.isboundto(0x01, 0x02):
        serialRegTable[address - 1][] = data

    elif address == 0x0F: IF = data
    elif address == 0x04: DIV = 0

    elif address.isboundto(0x05, 0x07):
        timerRegTable[address - 5][] = data

    elif address.isboundto(0x40, 0x4B):
        ppuRegTable[address and 0xF][] = data

    elif address == 0x50:
        booting = false

proc getLCDC*(lct: LCDCType): bool = return LCDC.testBit(lct.ord)
proc getLCDS*(lst: LCDSType): bool = return STAT.testBit(lst.ord)

proc sendIntReq*(ISR: IntType): void =
    setBit(IF, ISR.ord)

proc `LCDS=`*(lst: LCDSType, value: bool): void = 
    if value: STAT.setBit(lst.ord) 
    else: STAT.clearBit(lst.ord)

proc setMode*(mode: PPUStateType): void =
    STAT.clearBits(0, 1)
    STAT = STAT or mode.ord.uint8

proc getTileMapBase*(win: bool = false): uint16 =
    let flag = if win: getLCDC(WINTILEMAPAREA) else: getLCDC(BGTILEMAPAREA)
    return if flag: 0x9C00 else: 0x9800

proc getTileDataBase*(): uint16 = 
    return if getLCDC(BGANDWINTILEDATAAREA): 0x8000 else: 0x9000

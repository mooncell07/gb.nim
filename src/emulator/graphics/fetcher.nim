import ../[io, types, utils]
import bus

import deques
import bitops
import sdl2

const DEFAULT_PALETTE = [sdl2.color(0xE0, 0xF8, 0xD0, 0xFF),
                        sdl2.color(0x88, 0xC0, 0x70, 0xFF),
                        sdl2.color(0x34, 0x68, 0x56, 0xFF),
                        sdl2.color(0x8, 0x18, 0x20, 0xFF)]

type
    TileFetcher* = ref object
        state*: TileFetcherStateType

        internalX*: uint16
        tileNum*: uint8
        tileDataAddr*: uint16
        tileLo*: uint8

        tileRowBuffer: array[8, Color]
        FIFO* = initDeque[Color](8)

        delayLength*: int = 2
        isWindowVisible*: bool

proc getTileDataOffset(tileNum: uint8): uint16 =
    if getLCDC(BGANDWINTILEDATAAREA):
        return getTileDataBase() + (uint16(tileNum) * 16)
    return getTileDataBase() + (uint16(cast[int8](tileNum)) * 16)

proc getTileRow(f: TileFetcher): uint16 =
    if not f.isWindowVisible:
        return (((LY + SCY) mod 8).uint16 * 2)
    return (WLY mod 8).uint16 * 2

proc internalY(f: TileFetcher): uint16 =
    if not f.isWindowVisible:
        return (((LY + SCY) and 0xFF).float / 8.0).uint16 * 32
    return (WLY.float / 8.0).uint16 * 32

proc selectColor*(code: u2): Color =
    let index = code.int * 2
    return DEFAULT_PALETTE[BGP.bitsliced(index..(index+1))]

proc loadPixelRow(f: TileFetcher, lo, hi: uint8): void =
    var revX: int
    for x in countdown(7, 0):
        f.tileRowBuffer[revX] = selectColor((hi.testBit(x).uint8 shl 1) or
                lo.testBit(x).uint8)
        inc revX

proc tick*(f: TileFetcher): void =
    if f.delayLength > 0:
        dec f.delayLength
        return

    case f.state
    of GETTILE:
        f.tileNum = readByte(getTileMapBase(win = f.isWindowVisible) + ((
                f.internalX + f.internalY()) and 0x3FF))
        f.state = GETTILEDATALOW

    of GETTILEDATALOW:
        f.tileDataAddr = getTileDataOffset(f.tileNum) + f.getTileRow()
        f.tileLo = readByte(f.tileDataAddr)
        f.state = GETTILEDATAHIGH

    of GETTILEDATAHIGH:
        f.loadPixelRow(f.tileLo, readByte(f.tileDataAddr + 1))
        f.state = SLEEP

    of SLEEP:
        f.state = PUSH

    of PUSH:
        if f.FIFO.len() <= 8:
            for i in 0..7:
                f.FIFO.addLast(f.tileRowBuffer[i])
            f.internalX = (f.internalX + 1) mod 32
        f.state = GETTILE

proc fetch(f: TileFetcher, xPos: uint16): void =
    f.state = GETTILE
    f.internalX = xPos
    f.delayLength = 2
    f.FIFO.clear()

proc fetchBackground*(f: TileFetcher): void =
    f.fetch((SCX.float / 8.0).uint16 and 0x1F)

proc fetchWindow*(f: TileFetcher): void =
    f.fetch((((LX - (WX - 7))).float / 8.0).uint16 and 0x1F)

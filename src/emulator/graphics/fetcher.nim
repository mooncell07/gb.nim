import ../[io, types, utils]
import bus
import deques
import bitops
import sdl2
import algorithm
import logging
import strformat

const DEFAULT_PALETTE = [sdl2.color(0xE0, 0xF8, 0xD0, 0xFF), #00 - WHITE
                        sdl2.color(0x88, 0xC0, 0x70, 0xFF), #01 - LIGHT GRAY
                        sdl2.color(0x34, 0x68, 0x56, 0xFF), #10 - DARK GRAY
                        sdl2.color(0x8, 0x18, 0x20, 0xFF)] #11 - BLACK

type
    Sprite* = ref object
        x*: uint8
        y*: uint8
        tileNum*: uint8
        flags*: uint8
        height*: uint16

    Pixel* = ref object
        colorCode*: uint8
        palette1*: bool
        priority*: bool

    Fetcher* = ref object
        state*: uint8
        spriteState*: uint8

        internalX*: uint16
        tileNum*: uint8
        tileDataAddr*: uint16
        tileLo*: uint8
        tileSlice: array[8, uint8]
        tFIFO* = initDeque[Pixel](8)

        isWindowVisible*: bool

        sprites*: seq[Sprite]
        spriteDataAddr*: uint16
        spriteLo*: uint8
        spriteSlice: array[8, uint8]
        currSprite*: Sprite
        sFIFO* = initDeque[Pixel](8)

        firstInstance*: bool
        tickingSprite*: bool

proc getTileDataOffset(tileNum: uint8): uint16 =
    if getLCDC(BGANDWINTILEDATAAREA):
        return getTileDataBase() + (uint16(tileNum) * 16)
    return getTileDataBase() + (uint16(cast[int8](tileNum)) * 16)

proc getTileRow(f: Fetcher): uint16 =
    if not f.isWindowVisible:
        return (((LY + SCY) mod 8).uint16 * 2)
    return (WLY mod 8).uint16 * 2

proc internalY(f: Fetcher): uint16 =
    if not f.isWindowVisible:
        return (((LY + SCY) and 0xFF).float / 8.0).uint16 * 32
    return (WLY.float / 8.0).uint16 * 32

proc getColorIndex*(code: uint8, obj: bool = false, palette1: bool = false): uint8 =
    let index = code.int * 2

    if obj:
        if palette1:
            return (OBP1.bitsliced(index..(index+1))).uint8
        return (OBP0.bitsliced(index..(index+1))).uint8
    return (BGP.bitsliced(index..(index+1))).uint8

proc searchColor*(index: uint8): Color = return DEFAULT_PALETTE[index]

proc fetchPixelSlice(f: Fetcher, lo, hi: uint8, sprite: bool = false): void =
    var 
        revX: int
        cc: uint8

    for x in countdown(7, 0):
        cc = (hi.testBit(x).uint8 shl 1) or lo.testBit(x).uint8
        if sprite: f.spriteSlice[revX] = cc
        else: f.tileSlice[revX] = cc

        inc revX

proc tick*(f: Fetcher): void =
    case f.state
    of 0:
        f.state = 1
    
    of 1:
        f.tileNum = readByte(getTileMapBase(win = f.isWindowVisible) + ((
                    f.internalX + f.internalY()) and 0x3FF))
        f.state = 2
    
    of 2:
        f.state = 3

    of 3:
        f.tileDataAddr = getTileDataOffset(f.tileNum) + f.getTileRow()
        f.tileLo = readByte(f.tileDataAddr)
        f.state = 4

    of 4:
        f.state = 5

    of 5:
        f.fetchPixelSlice(f.tileLo, readByte(f.tileDataAddr + 1))
        f.state = 6
        if f.firstInstance:
            f.state = 0
            f.firstInstance = false
            return

    of 6:
        if (f.tFIFO.len() != 0):
            return

        for i in 0..7:
            f.tFIFO.addLast(Pixel(colorCode: f.tileSlice[i]))

        f.internalX = (f.internalX + 1) mod 32
        f.state = 0

    else:
        logger.log(lvlError, fmt"TILE FETCHER REACHED AN UNKNOWN STATE. (state: {f.state})")

proc spriteTick*(f: Fetcher): void =
    case f.spriteState
    of 0:
        if f.currSprite.height == 16: f.currSprite.tileNum = (f.currSprite.tileNum and 0xFE)
        var yOff = (LY.uint16 - f.currSprite.y.uint16 + 16)
        if f.currSprite.flags.testBit(6): yOff = (f.currSprite.height - 1 - yOff)

        f.spriteDataAddr = 0x8000 + (uint16(f.currSprite.tileNum) * 16) + (yOff * 2)
        f.spriteLo = readByte(f.spriteDataAddr)
        f.spriteState = 1

    of 1:
        f.fetchPixelSlice(f.spriteLo, readByte(f.spriteDataAddr + 1), sprite=true)
        f.spriteState = 2

    of 2:
        let residualAmount = f.sFIFO.len()
        if f.currSprite.flags.testBit(5): f.spriteSlice.reverse()

        for i in 0..7:
            let
                cc = f.spriteSlice[i]
                px = Pixel(colorCode: cc, palette1: f.currSprite.flags.testBit(4), priority: f.currSprite.flags.testBit(7))

            if (residualAmount >= (i+1)):
                let residualPixel = f.sFIFO[i]
                if (residualPixel.colorCode == 0) and (cc != 0): f.sFIFO[i] = px

            else: f.sFIFO.addLast(px)

        f.sprites.delete(0)
        f.spriteState = 0
        f.tickingSprite = false

    else:
        logger.log(lvlError, fmt"SPRITE FETCHER REACHED AN UNKNOWN STATE. (state: {f.spriteState})")

proc fetch(f: Fetcher, xPos: uint16): void =
    f.state = 0
    f.internalX = xPos
    f.tFIFO.clear()

proc fetchBackground*(f: Fetcher): void =
    f.fetch((SCX.float / 8.0).uint16 and 0x1F)

proc fetchWindow*(f: Fetcher): void =
    var saturatedWX = WX - 7
    if WX <= 6: saturatedWX = 0
    f.fetch((((LX - saturatedWX)).float / 8.0).uint16 and 0x1F)

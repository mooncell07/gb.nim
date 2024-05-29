import ../[io, types, utils]
import fetcher as pixelFetcher
import lcd
import bitops
import deques
import sdl2
import bus
import algorithm
import sugar
import logging
import strformat

var
    state: PPUStateType
    dots: int
    frames: int

    blockIntLine: bool
    isIntLineUp: bool
    fetcher = Fetcher()
    incrWLY: bool
    windowInit: bool = true
    windowTrigger: bool
    dropPixels: uint8

proc searchSprites*(): void =
    for i in 0..40:
        if len(fetcher.sprites) == 10:
            break

        let 
            spriteY = oam[i * 4]
            spriteX = oam[i * 4 + 1]
            tileNum = oam[i * 4 + 2]
            flags = oam[i * 4 + 3]

            spriteHeight: uint8 = if getLCDC(OBJSIZE): 16 else: 8

        if ((LY + 16) >= spriteY) and ((LY + 16) < (spriteY + spriteHeight)) and (spriteX > 0):
            fetcher.sprites.add(Sprite(x: spriteX, y: spriteY, tileNum: tileNum, flags: flags, height: spriteHeight))

    sort(fetcher.sprites, (a, b: Sprite) => cmp(a.x, b.x), SortOrder.Ascending)

proc isWindowEnabled*(flag: var bool): bool =
    if (LY == WY):
        windowTrigger = true

    flag = getLCDC(WINEN) and windowTrigger and (LX >= (WX - 7)) and WY.isboundto(0, 143) and (WX-7).isboundto(0, 159)
    return flag

proc getTileColor*(colorCode: uint8): Color =
    if getLCDC(BGANDWINEN): return searchColor(colorCode)
    else: return searchColor(BGP.bitsliced(0..1))

proc nextLine(): void =
    inc LY
    if incrWLY:
        inc WLY

    if LY == LYC:
        COINCIDENCE.LCDS = true
        if getLCDS(LYCINT):
            blockIntLine = true
    else:
        COINCIDENCE.LCDS = false

proc executeInterrupts(): void =
    if getLCDS(MODE2INT) and (state == OAMSEARCH):
        blockIntLine = true

    elif getLCDS(MODE1INT) and (state == VBLANK):
        blockIntLine = true

    elif getLCDS(MODE0INT) and (state == HBLANK):
        blockIntLine = true

    if (not isIntLineUp) and blockIntLine:
        sendIntReq(INTSTAT)

proc switchMode(t: PPUStateType): void =
    state = t
    setMode(t)

proc tick*(): void =
    if not getLCDC(LCDPPUEN):
        setMode(HBLANK)
        return

    inc dots
    isIntLineUp = blockIntLine
    blockIntLine = false

    case state
    of OAMSEARCH:
        if dots == 80:
            fetcher.fetchBackground()
            dropPixels = SCX mod 8
            searchSprites()
            switchMode(PIXELTRANSFER)

    of PIXELTRANSFER:
        if fetcher.tickingSprite: 
            fetcher.spriteTick()
        else:
            if (fetcher.sprites.len() != 0):
                if (fetcher.sprites[0].x <= (LX + 8)):
                    fetcher.currSprite = fetcher.sprites[0]
                    fetcher.tickingSprite = true
                    fetcher.spriteTick()

        if not fetcher.tickingSprite:
            fetcher.tick()

        if isWindowEnabled(fetcher.isWindowVisible):
            incrWLY = true
            if windowInit:
                fetcher.fetchWindow()
                windowInit = false
                return

        if (fetcher.tFIFO.len() > 0) and not fetcher.tickingSprite:

            if dropPixels > 0:
                dropPixels -= 1
                return

            var 
                tilePixel = fetcher.tFIFO.popFirst()
                tilePixelColorIndex = getColorIndex(tilePixel.colorCode)
                tilePixelColor = getTileColor(tilePixelColorIndex)

                finalColor: Color

            if (fetcher.sFIFO.len() > 0):
                var 
                    spritePixel = fetcher.sFIFO.popFirst()
                    spritePixelColorIndex = getColorIndex(spritePixel.colorCode, true, spritePixel.palette1)
                    spritePixelColor = searchColor(spritePixelColorIndex)

                if (spritePixel.colorCode == 0) or (spritePixel.priority and (tilePixel.colorCode != 0)):
                    finalColor = tilePixelColor
                else:
                    if getLCDC(OBJEN): finalColor = spritePixelColor
                    else: finalColor = tilePixelColor

            else: finalColor = tilePixelColor

            drawPixel(finalColor)
            inc LX

        if LX == 160:
            let dotsConsumed = dots - 80
            if (dotsConsumed < 172) or (dotsConsumed > 289) :
                logger.log(lvlWarn, fmt"MODE 3 UNDER-/OVER-FLEW THE MIN/MAX DOT LIMIT. (Dots: {dotsConsumed})")

            switchMode(HBLANK)

    of HBLANK:
        if dots == 456:
            nextLine()
            dots = 0
            LX = 0
            windowInit = true
            incrWLY = false
            fetcher.firstInstance = true
            fetcher.sprites = @[]

            if LY == 144:
                renderFrame()
                switchMode(VBLANK)
            else:
                switchMode(OAMSEARCH)

    of VBLANK:
        if dots == 456:
            dots = 0
            nextLine()
            sendIntReq(INTVBLANK)

            if LY == 154:
                inc frames
                LY = 0
                WLY = 0
                windowTrigger = false
                switchMode(OAMSEARCH)

    executeInterrupts()

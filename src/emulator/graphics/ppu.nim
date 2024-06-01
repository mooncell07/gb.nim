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

    var saturatedWX = WX - 7
    if WX <= 6: saturatedWX = 0

    flag = getLCDC(WINEN) and windowTrigger and (LX >= saturatedWX) and WY.isboundto(0, 143) and saturatedWX.isboundto(0, 159)
    return flag

proc getTileColor*(colorCode: uint8): Color =
    if getLCDC(BGANDWINEN): return searchColor(colorCode)
    else: return searchColor(BGP.bitsliced(0..1))

proc checkStatInt(v: uint8): bool =
    return STAT.testBit(v)

proc nextLine(): void =
    inc LY
    if incrWLY:
        inc WLY

    if LY == LYC:
        STAT.setBit(2)
        if checkStatInt(6):
            sendIntReq(INTSTAT)
    else:
        STAT.clearBit(2)

proc switchMode(t: PPUStateType): void =
    STAT.clearBits(0,1)
    STAT = STAT or t.ord.uint8
    state = t
    if state != PIXELTRANSFER and checkStatInt((t.ord + 3).uint8):
        sendIntReq(INTSTAT)

proc tick*(): void =
    if not getLCDC(LCDPPUEN):
        switchMode(HBLANK)
        return

    inc dots

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
            let tilePixel = fetcher.tFIFO.popFirst()
            if dropPixels > 0:
                dropPixels -= 1
                return

            var
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
            fetcher.sFIFO.clear()

            if LY >= 144:
                renderFrame()
                switchMode(VBLANK)
                sendIntReq(INTVBLANK)
            else:
                switchMode(OAMSEARCH)

    of VBLANK:
        if dots == 456:
            dots = 0
            nextLine()

            if LY == 154:
                inc frames
                LY = 0
                WLY = 0
                windowTrigger = false
                switchMode(OAMSEARCH)

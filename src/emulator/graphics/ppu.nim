import ../[io, types, utils]
import fetcher
import lcd

import bitops
import deques
import sdl2

var
    state: PPUStateType
    dots: int
    frames: int

    blockIntLine: bool
    isIntLineUp: bool
    tFetcher = TileFetcher()
    incrWLY: bool
    windowInit: bool = true
    windowTrigger: bool

proc isWindowEnabled*(flag: var bool): bool =
    if (LY == WY):
        windowTrigger = true

    flag = getLCDC(WINEN) and windowTrigger and (LX >= (WX - 7)) and WY.isboundto(
                0, 143) and (WX-7).isboundto(0, 159)
    return flag

proc getColor*(): Color =
    if getLCDC(BGANDWINEN): tFetcher.FIFO.popFirst() else: selectColor(
            BGP.bitsliced(0..1))

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
        return
    inc dots

    isIntLineUp = blockIntLine
    blockIntLine = false

    case state
    of OAMSEARCH:
        if dots == 80:
            LX = 0
            tFetcher.fetchBackground()
            switchMode(PIXELTRANSFER)

    of PIXELTRANSFER:
        if isWindowEnabled(tFetcher.isWindowVisible):
            incrWLY = true

            if windowInit:
                tFetcher.fetchWindow()
                windowInit = false
                return

        tFetcher.tick()

        if tFetcher.FIFO.len() >= 8:
            drawPixel(getColor())
            inc LX

        if LX == 160:
            switchMode(HBLANK)

    of HBLANK:
        if dots == 456:
            nextLine()
            dots = 0
            windowInit = true
            incrWLY = false

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

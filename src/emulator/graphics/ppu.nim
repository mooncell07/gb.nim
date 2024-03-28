import ../[io, types]
import fetcher
import deques
import lcd
import bitops

var
    state: PPUStateType
    dots: int
    frames: int
    LX: uint8

    blockIntLine: bool
    isIntLineUp: bool
    tileFetcher = TileFetcher()

proc nextLine(): void =
    inc LY

    if LY == LYC:
        COINCIDENCE.LCDS = true
        blockIntLine = true
    else:
        COINCIDENCE.LCDS = false

proc executeInterrutps(): void =
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
    inc dots
    isIntLineUp = blockIntLine
    blockIntLine = false

    case state
    of OAMSEARCH:
        if dots == 80:
            switchMode(PIXELTRANSFER)
            LX = 0
            tileFetcher.reset()

    of PIXELTRANSFER:
        tileFetcher.tick()

        if not tileFetcher.shouldShift:
            return

        let color = if getLCDC(BGANDWINEN): tileFetcher.FIFO.popFirst(
                ) else: selectColor(BGP.bitsliced(0..1))
        drawPixel(color)
        inc LX

        if LX == 160:
            switchMode(HBLANK)

    of HBLANK:
        if dots == 456:
            nextLine()
            dots = 0

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
                switchMode(OAMSEARCH)

    executeInterrutps()

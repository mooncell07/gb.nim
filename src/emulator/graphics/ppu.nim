import ../[io, types]

var
    state: PPUStateType
    dots: int
    frames: int
    LX: uint8

    blockIntLine: bool
    isIntLineUp: bool


proc nextLine(): void =
    inc LY
    LX = 0
    dots = 0

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

    of PIXELTRANSFER:
        inc LX

        if LX == 160:
            switchMode(HBLANK)

    of HBLANK:
        if dots == 456:
            nextLine()

            if LY == 144:
                switchMode(VBLANK)
            else:
                switchMode(HBLANK)

    of VBLANK:
        if dots == 456:
            nextLine()

            if LY == 154:
                inc frames
                LY = 0
                switchMode(OAMSEARCH)

    executeInterrutps()

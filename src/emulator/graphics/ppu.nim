import ../[io, types]

var
    state: PPUStateType
    dots: int
    frames: int
    LX: uint8


proc nextLine(): void =
    inc LY
    LX = 0
    dots = 0

proc switchMode(t: PPUStateType): void =
    state = t

proc tick*(): void =
    inc dots

    case state
    of OAMSearch:
        if dots == 80:
            switchMode(PixelTransfer)

    of PixelTransfer:
        inc LX

        if LX == 160:
            switchMode(Hblank)

    of Hblank:
        if dots == 456:
            nextLine()

            if LY == 144:
                switchMode(PPUStateType.Vblank)
            else:
                switchMode(Hblank)

    of Vblank:
        if dots == 456:
            nextLine()

            if LY == 154:
                inc frames
                LY = 0
                switchMode(OAMSearch)

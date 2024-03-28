var
    vram*: array[0x2000, uint8]
    oam*: array[0x100, uint8]

proc readByte*(address: uint16, obj: bool = false): uint8 =
    if obj:
        return oam[address - 0xFE00]
    return vram[address - 0x8000]

proc writeByte*(address: uint16, data: uint8, obj: bool = false): void =
    if obj:
        oam[address - 0xFE00] = data
        return

    vram[address - 0x8000] = data

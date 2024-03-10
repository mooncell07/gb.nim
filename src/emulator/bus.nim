import cartridge
import utils
import timer
import io

var
    rom*: ROM
    wram*: array[0x2000, uint8]
    hram*: array[0x80, uint8]


proc readByte*(address: uint16, incr = true): uint8 =
    if address.isboundto(0, 0x7FFF):
        result = rom.read(address)

    elif address.isboundto(0xC000, 0xDFFF):
        result = wram[address - 0xC000]

    elif address.isboundto(0xFF00, 0xFF7F):
        result = ioReadByte(address)

    elif address.isboundto(0xFF80, 0xFFFE):
        result = hram[address - 0xFF80]

    elif address == 0xFFFF:
        result = IE

    if incr:
        incCycle(1)

proc writeByte*(address: uint16, data: uint8, incr = true): void =
    if address.isboundto(0, 0x7FFF):
        rom.write(address, data)

    elif address.isboundto(0xC000, 0xDFFF):
        wram[address - 0xC000] = data

    elif address.isboundto(0xFF00, 0xFF7F):
        ioWriteByte(address, data)

    elif address.isboundto(0xFF80, 0xFFFE):
        hram[address - 0xFF80] = data

    elif address == 0xFFFF:
        IE = data

    if incr:
        incCycle(1)

proc writeWord*(address, data: uint16): void =
    writeByte(address, data.lsb)
    writeByte(address + 1, data.msb)

proc internal*(): void =
    incCycle(1)

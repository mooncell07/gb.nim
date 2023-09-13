import memory
import utils
import timer
import io

type
    Bus* = ref object
        rom*: ROM

#TODO: Add support for External RAM, OAM, IO and IE.

proc readByte*(self: Bus, address: uint16, incr = true): uint8 =
    if address.isboundto(0, 0x8000'u16):
        result = self.rom.read(address)

    elif address.isboundto(0xC000'u16, 0xDFFF'u16):
        result = wram[address - 0xC000'u16]

    elif address.isboundto(0xFF80'u16, 0xFFFE'u16):
        result = hram[address - 0xFF80'u16]

    elif address.isboundto(0xFF00'u16, 0xFF7F'u16):
        result = ioReadByte(address)

    if incr:
        incCycle(1)

proc writeByte*(self: Bus, address: uint16, data: uint8, incr = true): void =
    if address.isboundto(0, 0x8000'u16):
        self.rom.write(address, data)

    elif address.isboundto(0xC000'u16, 0xDFFF'u16):
        wram[address - 0xC000'u16] = data

    elif address.isboundto(0xFF80'u16, 0xFFFE'u16):
        hram[address - 0xFF80'u16] = data

    elif address.isboundto(0xFF00'u16, 0xFF7F'u16):
        ioWriteByte(address, data)

    if incr:
        incCycle(1)

proc writeWord*(self: Bus, address, data: uint16): void =
    self.writeByte(address, data.lsb)
    self.writeByte(address + 1, data.msb)

proc internal*(self: Bus): void =
    incCycle(1)

import io
import cartridge
import utils
import timer
import graphics/bus

type
    DMA* = ref object
        active*: bool
        currentByte: uint8
        currentIndex: uint8
        starting: bool
        initialDelay: uint8

proc tick(d: DMA): void


var
    rom*: ROM
    wram: array[0x2000, uint8]
    hram: array[0x80, uint8]
    bootRom*: string

    # TODO: add support for external ram
    mockExternalRam: array[0x2000, uint8]

    dma* = DMA()


template cycle(incr: bool = true): void =
    if not incr:
        return

    if dma.active:
        dma.tick()

    incCycle(1)

    if dma.starting:
        if dma.initialDelay > 1:
            dma.initialDelay -= 1

        else:
            dma.active = true

proc readByte*(address: uint16, incr = true, conflict = true): uint8 =
    if dma.active and (not conflict) and address.isboundto(0xFE00, 0xFFFF):
        result = wram[(address - 0xFE00) + 0x1E00]
        return

    if address.isboundto(0, 0x7FFF):

        if booting and address.isboundto(0, 0xFF):
            result = bootRom[address].uint8
        else:
            result = rom.read(address)

    elif address.isboundto(0x8000, 0x9FFF):
        result = bus.readByte(address)

    elif address.isboundto(0xA000, 0xBFFF):
        result = mockExternalRam[address - 0xA000]

    elif address.isboundto(0xC000, 0xDFFF):
        result = wram[address - 0xC000]

    elif address.isboundto(0xE000, 0xFDFF): # mirror
        result = wram[address - 0xE000]

    elif address.isboundto(0xFE00, 0xFE9F):
        if dma.active and conflict:
            result = 0xFF
        else:
            result = bus.readByte(address, obj = true)

    elif address.isboundto(0xFF00, 0xFF7F):
        result = getIoReg((address and 0xFF).int)

    elif address.isboundto(0xFF80, 0xFFFE):
        result = hram[address - 0xFF80]

    elif address == 0xFFFF:
        result = IE

    cycle(incr)

proc writeByte*(address: uint16, data: uint8, incr = true): void =
    if address.isboundto(0, 0x7FFF):
        rom.write(address, data)

    elif address.isboundto(0x8000, 0x9FFF):
        bus.writeByte(address, data)

    elif address.isboundto(0xA000, 0xBFFF):
        mockExternalRam[address - 0xA000] = data

    elif address.isboundto(0xC000, 0xDFFF):
        wram[address - 0xC000] = data

    elif address.isboundto(0xE000, 0xFDFF):
        wram[address - 0xE000] = data

    elif address.isboundto(0xFE00, 0xFE9F):
        bus.writeByte(address, data, obj = true)

    elif address.isboundto(0xFF00, 0xFF7F):
        setIoReg((address and 0xFF).int, data)
        if address == 0xFF46:
            dma.starting = true
            dma.initialDelay = 2

    elif address.isboundto(0xFF80, 0xFFFE):
        hram[address - 0xFF80] = data

    elif address == 0xFFFF:
        IE = data

    cycle(incr)

proc writeWord*(address, data: uint16): void =
    writeByte(address, data.lsb)
    writeByte(address + 1, data.msb)

proc internal*(): void =
    cycle()

proc tick(d: DMA): void =
    let address = io.DMA.uint16 shl 8
    d.currentByte = readByte(address + d.currentIndex, incr = false,
            conflict = false)

    bus.writeByte(0xFE00 + d.currentIndex.uint16, d.currentByte, obj = true)
    inc d.currentIndex

    if d.currentIndex == 0xA0:

        d.active = false
        d.starting = false
        d.initialDelay = 0
        d.currentIndex = 0

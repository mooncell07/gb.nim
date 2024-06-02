import bitops
import utils

const RAMBANKS = [0, 1, 2, 4, 16, 8]

var
    bootRom*: string
    romData*: string
    extRam*: seq[uint8]
    wram*: array[0x2000, uint8]
    hram*: array[0x80, uint8]

    romBankCount*: uint8
    ramSizeCode*: uint8
    extRamFlag*: bool

proc buildExternalMemory*(): void =
    extRam = newSeq[uint8](RAMBANKS[ramSizeCode] * 0x2000)

type
    MBC1* = ref object
        romBank*: uint8
        ramBank*: uint8
        modeFlag*: bool

proc read*(m: MBC1, address: uint16): uint8 =
    if address.isboundto(0x0, 0x3FFF):
        result = romData[address].uint8

    elif address.isboundto(0x4000, 0x7FFF):
        var highBankNum = m.romBank and (romBankCount - 1)
        let addrs = 0x4000 * highBankNum + (address - 0x4000)
        result = romData[addrs].uint8

    elif address.isboundto(0xA000, 0xBFFF):
        if extRamFlag:
            if (ramSizeCode > 0x02) and m.modeFlag:
                result = extRam[0x2000 * m.ramBank + (address - 0xA000)]
            else:
                result = extRam[address - 0xA000]
        else:
            result = 0xFF

proc intercept*(m: MBC1, address: uint16, data: uint8): void =
    if address.isboundto(0, 0x1FFF):
        extRamFlag = data.bitsliced(0..3) == 0xA

    elif address.isboundto(0x2000, 0x3FFF):
        let maskedData = (data and 0x1F)
        m.romBank = maskedData mod romBankCount
        if m.romBank == 0 and (maskedData < romBankCount):
            m.romBank = 1

    elif address.isboundto(0x4000, 0x5FFF):
        m.ramBank = data.bitsliced(0..1)

    elif address.isboundto(0x6000, 0x7FFF):
        m.modeFlag = data.testBit(0)
    
    elif address.isboundto(0xA000, 0xBFFF):
        if extRamFlag:
            if (ramSizeCode > 0x02) and m.modeFlag:
                extRam[0x2000 * m.ramBank + (address - 0xA000)] = data
            else:
                extRam[address - 0xA000] = data

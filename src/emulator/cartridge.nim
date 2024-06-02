import utils
import mmu

type
    ROM* = ref object
        mapper: MBC1

        # Headers...
        title: string
        licensee: string
        romType: uint8
        romSize: int
        romVer: uint8
        destinationCode: uint8
        checksum: uint8

    RomError* = object of ValueError

proc read*(self: ROM, address: uint16): uint8 =
    return self.mapper.read(address)

proc write*(self: ROM, address: uint16, data: uint8): void =
    self.mapper.intercept(address, data)

proc fillHeaders(self: ROM): void =
    self.title = romData[0x0134..0x0143]
    self.title[0xF] = '\0'
    self.licensee = romData[0x0144..0x0145]

    self.romType = romData[0x0147].uint8
    self.romSize = 32 shl romData[0x0148].int
    romBankCount = uint8(self.romSize / 16)
    ramSizeCode = romData[0x0149].uint8

    self.romVer = romData[0x014C].uint8
    self.destinationCode = romData[0x014A].uint8

proc runChecksum(self: ROM): void =
    var checksum: uint8;

    for i in 0x0134..0x014C:
        checksum = checksum - romData[i].uint8 - 1

    if checksum.lsb == romData[0x014D].uint8:
        self.checksum = checksum

    else:
        raise newException(RomError, "Checksum Failed for the ROM.")

proc newRom*(filepath: string): ROM =
    let self = ROM(mapper: MBC1(romBank: 1, ramBank: 1, modeFlag: false))
    romData = readFile(filepath)
    self.runChecksum()
    self.fillHeaders()
    buildExternalMemory()

    return self

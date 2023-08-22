import utils

var
    wram*: array[0x2000, uint8]
    hram*: array[0x80, uint8]


type
    ROM* = ref object
        data: string

        # Headers...
        title: string
        licensee: string
        romType: uint8
        romSize: int
        ramSize: uint8
        romVer: uint8
        destinationCode: uint8
        checksum: uint8

    RomError = object of ValueError

proc read*(self: ROM, address: uint16): uint8 =
    return self.data[address].uint8

proc write*(self: ROM, address: uint16, data: uint8): void =
    self.data[address] = data.char

proc fillHeaders(self: ROM): void =
    self.title = self.data[0x0134..0x0143]
    self.title[0xF] = '\0'
    self.licensee = self.data[0x0144..0x0145]

    self.romType = self.data[0x0147].uint8
    self.romSize = 32 shl self.data[0x0148].uint8
    self.ramSize = self.data[0x0149].uint8

    self.romVer = self.data[0x014C].uint8
    self.destinationCode = self.data[0x014A].uint8

proc runChecksum(self: ROM): void =
    var checksum: uint8;

    for i in 0x0134..0x014C:
        checksum = checksum - self.data[i].uint8 - 1

    if checksum.lsb == self.data[0x014D].uint8:
        self.checksum = checksum

    else:
        raise newException(RomError, "Checksum Failed for the ROM.")

proc newRom*(filepath: string): ROM =
    let self = ROM(data: readFile(filepath))
    self.runChecksum()
    self.fillHeaders()

    return self

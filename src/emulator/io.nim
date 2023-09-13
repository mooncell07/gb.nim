import utils

var serialData: array[2, uint8]

proc ioReadByte*(address: uint16): uint8 =
    if address == 0xFF01'u16:
        result = serialData[0]
    elif address == 0xFF02'u16:
        result = serialData[1]

    elif address.isboundto(0xFF40'u16, 0xFF4B'u16):
        result = 0x90'u8

proc ioWriteByte*(address: uint16, data: uint8): void =
    if address == 0xFF01'u16:
        serialData[0] = data
    elif address == 0xFF02'u16:
        serialData[1] = data

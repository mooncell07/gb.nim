import bitops

import types
import utils

var r8: array[0..7, uint8]
var pc*: uint16
var sp*: uint16
var f*: uint8

template getReg*[R: R8](r: R): uint8 =
    when r == aHL:
        bus.readByte(getReg(HL))
    else:
        r8[ord(r)]

template getReg*[RP: R16](r: RP): uint16 =
    var value: uint16

    when r == BC: value = concat(hi = r8[ord(B)], lo = r8[ord(C)])
    elif r == DE: value = concat(hi = r8[ord(D)], lo = r8[ord(E)])
    elif r == HL: value = concat(hi = r8[ord(H)], lo = r8[ord(L)])
    elif r == SP: value = sp
    elif r == AF: value = concat(hi = r8[ord(A)], lo = f)

    value

template setReg*[N: uint8](r: R8, n: N): void =
    when r == aHL:
        bus.writeByte(getReg(HL), n)
    else:
        r8[ord(r)] = n

template setReg*[N: uint16](r: R16, n: N): void =
    when r == BC:
        r8[ord(B)] = msb(n)
        r8[ord(C)] = lsb(n)

    elif r == DE:
        r8[ord(D)] = msb(n)
        r8[ord(E)] = lsb(n)

    elif r == HL:
        r8[ord(H)] = msb(n)
        r8[ord(L)] = lsb(n)

    elif r == SP: sp = n

    elif r == AF:
        r8[ord(A)] = msb(n)
        f = lsb(n)

template `writeZ=`*(f: var uint8, value: bool): void =
    when value == false: f.clearBit(ord(ftZ))
    else: f.setBit(ord(ftZ))

template `writeN=`*(f: var uint8, value: bool): void =
    when value == false: f.clearBit(ord(ftN))
    else: f.setBit(ord(ftN))

template `writeH=`*(f: var uint8, value: bool): void =
    when value == false: f.clearBit(ord(ftH))
    else: f.setBit(ord(ftH))

template `writeC=`*(f: var uint8, value: bool): void =
    when value == false: f.clearBit(ord(ftC))
    else: f.setBit(ord(ftC))

template getFlag*(v: flags): bool =
    f.testBit(ord(v))

proc resetRegState*(): void {.inline.} =
    setReg(A, 0x01)
    setReg(B, 0x00)
    setReg(C, 0x13)
    setReg(D, 0x00)
    setReg(E, 0xD8)
    setReg(H, 0x01)
    setReg(L, 0x4D)

    f.writeC = true; f.writeH = true; f.writeZ = true
    f.writeN = false

    setReg(SP, 0xFFFE)
    pc = 0x0100

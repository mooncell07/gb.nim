import bitops
import bus as memBus
import types
import utils

var r8: array[0..7, uint8]
var pc*: uint16
var sp*: uint16
var f*: uint8

var bus: Bus

proc getReg*(r: R16): uint16 =
    case r
    of BC:
        concat(hi = r8[ord(B)], lo = r8[ord(C)])
    of DE:
        concat(hi = r8[ord(D)], lo = r8[ord(E)])
    of HL:
        concat(hi = r8[ord(H)], lo = r8[ord(L)])
    of SP:
        sp
    of AF:
        concat(hi = r8[ord(A)], lo = f)

proc getReg*(r: R8): uint8 =
    if r == aHL:
        bus.readByte(getReg(HL))
    else:
        r8[ord(r)]

proc setReg*(r: R8, n: uint8): void =
    if r == aHL:
        bus.writeByte(getReg(HL), n)
    else:
        r8[ord(r)] = n

proc setReg*(r: R16, n: uint16): void =
    case r
    of BC:
        r8[ord(B)] = msb(n)
        r8[ord(C)] = lsb(n)

    of DE:
        r8[ord(D)] = msb(n)
        r8[ord(E)] = lsb(n)

    of HL:
        r8[ord(H)] = msb(n)
        r8[ord(L)] = lsb(n)

    of SP:
        sp = n

    of AF:
        r8[ord(A)] = msb(n)
        f = lsb(n)

proc `writeZ=`*(f: var uint8, value: bool): void =
    if value == false: f.clearBit(ord(ftZ))
    else: f.setBit(ord(ftZ))

proc `writeN=`*(f: var uint8, value: bool): void =
    if value == false: f.clearBit(ord(ftN))
    else: f.setBit(ord(ftN))

proc `writeH=`*(f: var uint8, value: bool): void =
    if value == false: f.clearBit(ord(ftH))
    else: f.setBit(ord(ftH))

proc `writeC=`*(f: var uint8, value: bool): void =
    if value == false: f.clearBit(ord(ftC))
    else: f.setBit(ord(ftC))

template getFlag*(v: flags): bool =
    f.testBit(ord(v))

proc getCC*(cc: CC): bool {.inline.} =
    case cc
    of ccNZ:
        not getFlag(ftZ)
    of ccZ:
        getFlag(ftZ)
    of ccNC:
        not getFlag(ftC)
    of ccC:
        getFlag(ftC)

proc resetRegState*(mbus: var Bus): void {.inline.} =
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
    bus = mbus

import bitops
import bus as memBus
import types
import utils

var r8: array[R8Type, uint8]
var pc*: uint16
var sp*: uint16
var f*: uint8

var bus: Bus

proc getReg*(r: R16Type): uint16 =
    case r
    of BC:
        concat(hi = r8[B], lo = r8[C])
    of DE:
        concat(hi = r8[D], lo = r8[E])
    of HL:
        concat(hi = r8[H], lo = r8[L])
    of SP:
        sp
    of AF:
        concat(hi = r8[A], lo = f)

proc getReg*(r: R8Type): uint8 {.inline.} =
    if r == aHL:
        return bus.readByte(getReg(HL))
    return r8[r]

proc setReg*(r: R8Type, n: uint8): void {.inline.} =
    if r == aHL:
        bus.writeByte(getReg(HL), n)
    else:
        r8[r] = n

proc setReg*(r: R16Type, n: uint16): void =
    case r
    of BC:
        r8[B] = msb(n); r8[C] = lsb(n)
    of DE:
        r8[D] = msb(n); r8[E] = lsb(n)
    of HL:
        r8[H] = msb(n); r8[L] = lsb(n)
    of SP:
        sp = n
    of AF:
        r8[A] = msb(n); f = lsb(n)


proc getFlag*(ft: FlagType): bool {.inline.} =
    return f.testBit(ord(ft))

proc setFlag(f: var uint8, ft: FlagType, v: bool): void {.inline.} =
    if v:
        f.setBit(ord(ft))
    else:
        f.clearBit(ord(ft))


proc `Z=`*(f: var uint8, value: bool): void =
    setFlag(f, ftZ, value)

proc `N=`*(f: var uint8, value: bool): void =
    setFlag(f, ftZ, value)

proc `H=`*(f: var uint8, value: bool): void =
    setFlag(f, ftH, value)

proc `C=`*(f: var uint8, value: bool): void =
    setFlag(f, ftC, value)


proc getCC*(cc: CCType): bool {.inline.} =
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

    f.C = true; f.H = true; f.Z = true
    f.N = false

    setReg(SP, 0xFFFE)
    pc = 0x0100
    bus = mbus

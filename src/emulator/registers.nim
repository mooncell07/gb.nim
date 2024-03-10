import bitops

import bus
import types
import utils

var
    r8: array[R8Type, uint8] = [0x00, 0x13, 0x00, 0xD8, 0x01, 0x4D, 0x00, 0x01]
    pc*: uint16 = 0x0100
    sp*: uint16 = 0xFFFE
    f*: uint8 = 0xB0


proc getReg*(r: R16Type): uint16 {.inline.} =
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
        return readByte(getReg(HL))
    return r8[r]

proc setReg*(r: R8Type, n: uint8): void {.inline.} =
    if r == aHL:
        writeByte(getReg(HL), n)
    else:
        r8[r] = n

proc setReg*(r: R16Type, n: uint16): void {.inline.} =
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
        r8[A] = msb(n); f = (n and 0xFFF0'u16).uint8

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
    setFlag(f, ftN, value)

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

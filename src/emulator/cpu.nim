import os

import bus as memBus
import memory
import registers
import utils
import types
import strutils

var bus*: Bus
var currOp*: uint8
var ime*: bool


proc newCpu*(): void =
    let args = commandLineParams()

    if args.len() > 0:
        bus = Bus(rom: memory.newROM(args[0]))
    else:
        raise newException(RomError, "No ROM detected.")
    resetRegState(bus)

proc fetch*(): uint8 {.inline.} =
    result = bus.readByte(pc)
    inc pc

proc fetchWord*(): uint16 {.inline.} =
    let
        lo = fetch()
        hi = fetch()

    return concat(lo, hi)

proc opJP(): void =
    pc = fetchWord()
    bus.internal()

proc opLDr_r(src: R8Type, dest: R8Type): void =
    setReg(src, getReg(dest))

proc opLDr_n(reg: R8Type | R16Type): void =
    when reg is R8Type: setReg(reg, fetch())
    else: setReg(reg, fetchWord())

proc opLDr_addr(reg: R8Type, address: uint16): void =
    setReg(reg, bus.readByte(address))

proc opLDaddr_r(address: uint16, reg: R8Type): void =
    bus.writeByte(address, getReg(reg))

proc opINC(reg: R8Type | R16Type): void =
    let
        value = getReg(reg)
        res = value + 1

    when reg is R8Type:
        f.Z = not res.bool
        f.N = false
        f.H = checkHalfCarry(value, 1)

    setReg(reg, res)

proc opDEC(reg: R8Type | R16Type): void =
    let
        value = getReg(reg)
        res = value - 1

    when reg is R8Type:
        f.Z = not res.bool
        f.N = true
        f.H = checkHalfBorrow(value)

    setReg(reg, res)

proc opJR(offset: uint16): void =
    pc += offset
    bus.internal()

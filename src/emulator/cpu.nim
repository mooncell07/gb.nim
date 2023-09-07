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

proc opLDr_r(src, dest: R8Type): void =
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
        f.H = checkHalfBorrow(value, 1)

    setReg(reg, res)

proc opJR(offset: uint16): void =
    pc += offset
    bus.internal()

proc opPUSH(reg: R16Type | uint16): void =
    bus.internal()
    var data: uint16

    when reg is R16Type:
        data = getReg(reg)
    else:
        data = reg

    dec sp
    bus.writeByte(sp, msb(data))
    dec sp
    bus.writeByte(sp, lsb(data))

proc opPOP(reg: R16Type): void =
    let lo = bus.readByte(sp)
    inc sp
    let hi = bus.readByte(sp)
    inc sp

    setReg(reg, concat(lo, hi))

proc opCALL(address: uint16): void =
    opPUSH(pc)
    pc = address

proc opRET(address: uint16): void =
    pc = address
    bus.internal()

proc alu(op: AluOp, data: uint8): void =
    let acc = getReg(A)
    var res: uint8

    case op
    of OR:
        res = acc or data
        f.N = false; f.H = false; f.C = false

    of CP:
        res = acc - data
        f.N = true
        f.H = checkHalfBorrow(acc, data)
        f.C = data > acc

    of AND:
        res = acc and data
        f.N = false; f.C = false
        f.H = true

    of XOR:
        res = acc xor data
        f.N = false; f.H = false; f.C = false

    of ADD:
        res = acc + data
        f.N = false
        f.H = checkHalfCarry(acc, data)
        f.C = acc > data

    of SUB:
        res = acc - data
        f.N = true
        f.H = checkHalfBorrow(acc, data)
        f.C = data > acc

    else:
        quit("OPCODE HANDLER NOT FOUND: " & currOp.toHex & " (" & $op & ")", 0)

    f.Z = not res.bool

    if op != CP:
        setReg(A, res)

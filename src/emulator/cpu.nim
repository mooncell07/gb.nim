import os

import bus as memBus
import memory
import registers
import bitops
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

proc RETUtil(): uint16 =
    let lo = bus.readByte(sp)
    inc sp
    let hi = bus.readByte(sp)
    inc sp

    return concat(lo, hi)

proc opJP(address: uint16, hl=false): void =
    pc = address
    if not hl:
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

proc opLDaddr_SP(): void =
    let nn = fetchWord()
    bus.writeByte(nn, lsb(sp))
    bus.writeByte(nn+1, msb(sp))

proc opLDRP_word(reg: R16Type, data: uint16): void =
    setReg(reg, data)
    bus.internal()

proc opINC(reg: R8Type | R16Type): void =
    let
        value = getReg(reg)
        res = value + 1

    when reg is R8Type:
        f.Z = res == 0
        f.N = false
        f.H = checkHalfCarry(value, 1)

    setReg(reg, res)

proc opDEC(reg: R8Type | R16Type): void =
    let
        value = getReg(reg)
        res = value - 1

    when reg is R8Type:
        f.Z = res == 0
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
        f.C = acc > res

    of SUB:
        res = acc - data
        f.N = true
        f.H = checkHalfBorrow(acc, data)
        f.C = data > acc
    
    of ADC:
        res = acc + data + getFlag(ftC).uint8
        f.N = false
        f.H = ((acc and 0xF) + (data and 0xF) + getFlag(ftC).uint8) > 0xF
        f.C = (acc.uint16 + data.uint16 + getFlag(ftC).uint16) > 0xFF
    
    of SBC:
        res = acc - getFlag(ftC).uint8 - data
        f.N = true
        f.H = ((data and 0xF) + getFlag(ftC).uint8) > (acc and 0xF)
        f.C = (data.uint16 + getFlag(ftC).uint8) > acc

    f.Z = res == 0

    if op != CP:
        setReg(A, res)

proc prefixHandler(): void =
    let 
        op = fetch()
        reg = R8Type(op.z)
        u8 = getReg(reg)

    var res: uint8

    case op.x
    of 0x0:
        let rot = PrefixOp(op.y)
        case rot
        of RL:
            res = (u8 shl 1) or getFlag(ftC).uint8
            f.Z = res == 0
            f.C = (u8 shr 7) != 0

        of RR:
            res = (u8 shr 1) or (getFlag(ftC).uint8 shl 7)
            f.Z = res == 0
            f.C = (u8 and 1) == 1

        of RLC:
            f.C = (u8 shr 7) != 0
            res = rotateLeftBits(u8, 1) or getFlag(ftC).uint8
            f.Z = res == 0

        of RRC:
            f.C = (u8 and 1) == 1
            res = rotateRightBits(u8, 1) or (0x80 and getFlag(ftC).uint8)
            f.Z = res == 0

        of SLA:
            res = (u8 shl 1)
            f.Z = res == 0
            f.C = (u8 shr 7) != 0

        of SRL:
            res = u8 shr 1
            f.Z = res == 0
            f.C = (u8 and 1) == 1

        of SRA:
            res = (u8 shr 1) or (u8 and 0x80)
            f.Z = res == 0
            f.C = (u8 and 1) == 1

        of SWAP:
            res = rotateLeftBits(u8, 4)
            f.Z = res == 0
            f.C = false

    of 0x1:
        f.Z = not getReg(reg).testBit(op.y.uint8)
        f.N = false
        f.H = true
    
    of 0x2:
        res = u8
        res.clearBit(op.y.uint8)

    of 0x3:
        res = u8
        res.setBit(op.y.uint8)

    if op.x != 1:
        setReg(reg, res)
        if op.x == 0:
            f.N = false; f.H = false;

proc opADDHL_RP(reg: R16Type): void =
    let 
        hl = getReg(HL)
        data = getReg(reg)

    setReg(HL, hl + data)
    f.N = false
    f.H = (hl and 0xFFF) + (data and 0xFFF) > 0xFFF
    f.C = (hl.uint32 + data.uint32) > 0xFFFF

    bus.internal()

proc opADDSP_i8(multiInts=true): void =
    let 
        data = signed(fetch())
        res = sp + data

    f.Z = false; f.N = false
    f.H = (sp and 0xF) + (data and 0xF) > 0xF
    f.C = (sp and 0xFF) + (data and 0xFF) > 0xFF

    bus.internal()

    if multiInts:
        bus.internal()
    sp = res

proc opRLCA(): void =
    let acc = getReg(A)
    f.C = (acc shr 7) != 0
    let data = rotateLeftBits(acc, 1) or getFlag(ftC).uint8
    f.Z = false; f.N = false; f.H = false
    setReg(A, data)

proc opRLA(): void =
    let 
        acc = getReg(A)
        data = (acc shl 1) or getFlag(ftC).uint8

    f.C = (acc shr 7) != 0
    f.Z = false; f.N = false; f.H = false
    setReg(A, data)

proc opRRA(): void =
    let 
        u8 = getReg(A)
        res = (u8 shr 1) or (getFlag(ftC).uint8 shl 7)

    f.Z = false; f.N = false; f.H = false
    f.C = (u8 and 1) == 1
    setReg(A, res)

proc opRRCA(): void =
    let acc = getReg(A)
    f.C = (acc and 1) == 1
    let data = rotateRightBits(acc, 1) or (0x80 and getFlag(ftC).uint8)
    f.Z = false; f.N = false; f.H = false
    setReg(A, data)
import os

import bus as memBus
import memory
import registers
import utils
import types
import options

var bus*: Bus
var currOp*: uint8


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
    let lo = fetch()
    let hi = fetch()

    return concat(lo, hi)

proc opJR(code = none(uint8)): void =
    let i8 = cast[int8](fetch()).uint16
    if code.isNone or getCC(CC(get(code))):
        pc += i8
        bus.internal()

proc opJP(code = none(uint8)): void =
    let u8 = fetchWord()
    pc = u8
    bus.internal()

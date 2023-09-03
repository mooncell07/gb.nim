import os

import bus as memBus
import memory
import registers
import utils
import types

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
    let 
        lo = fetch()
        hi = fetch()

    return concat(lo, hi)

import os

import bus as memBus
import memory
import registers

var bus: Bus

proc newCpu*(): void =
    resetRegState()

    let args = commandLineParams()

    if args.len() > 0:
        bus = Bus(rom: memory.newROM(args[0]))
    else:
        raise newException(RomError, "No ROM detected.")

proc fetch*(): uint8 {.inline.} =
    result = bus.readByte(pc)
    inc pc

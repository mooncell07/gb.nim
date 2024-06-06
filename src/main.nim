import emulator/[bus, cartridge, timer, mmu]
import emulator/graphics/[lcd]
import os

include irq

proc init(): void =
    let args = commandLineParams()

    if args.len > 0:
        bus.rom = newRom(args[0])
        bootRom = readFile("roms/bootrom.gb")

    lcd.init()

proc step(): void =
    if not halted: cpu.tick()
    else: incCycle(1)
    checkPendingIRQs()
    if IMERising: IME = true

when isMainModule:
    init()

    while true:
        step()

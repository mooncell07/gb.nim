import bitops
import types
import io
import graphics/ppu

const CLKSEL = [9, 3, 5, 7]

proc getANDResult(): bool = testBit(DIV, CLKSEL[TAC.bitsliced(0..1)]) and TAC.testBit(2)

var 
    lateANDResult = getANDResult()
    cooldownCycles = 4
    reload = false
    isTimaUpdated: bool = false

proc toggleCooldown(): void =
    if cooldownCycles != 0:
        if TIMA != 0:
            isTimaUpdated = true
        cooldownCycles -= 1
        return

    if not isTimaUpdated:
        TIMA = TMA
        sendIntReq(INTTIMER)

    reload = false
    isTimaUpdated = false
    cooldownCycles = 4

proc tick(): void =
    let earlyANDResult = lateANDResult
    inc DIV
    lateANDResult = getANDResult()

    if (earlyANDResult and not lateANDResult):
        if (TIMA == 0xFF):
            TIMA = 0
            reload = true

        if not reload:
            inc TIMA

    if reload:
        toggleCooldown()
        return

proc incCycle*(m: int): void =
    for i in 0..<(m*4):
        tick()
        ppu.tick()

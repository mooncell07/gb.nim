import bitops

import types
import io
import utils
import graphics/ppu


proc clockSelect(): int =
    let freq: u2 = TAC.bitsliced(0..1)
    result = case freq
    of 0: 9
    of 1: 3
    of 2: 5
    of 3: 7

proc tick(): void =
    let oldDiv = DIV
    inc DIV

    let freq = clockSelect()
    if testBit(DIV, freq) and (not testBit(oldDIV, freq)) and TAC.testBit(2):
        if (TIMA == 0xFF):
            TIMA = TMA
            sendIntReq(INTTIMER)

        inc TIMA

proc incCycle*(m: int): void =
    for i in 0..<(m*4):
        tick()
        ppu.tick()

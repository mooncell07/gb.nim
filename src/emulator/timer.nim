import bitops
import types
import io
import graphics/ppu

const CLKSEL = [9, 3, 5, 7]

proc tick(): void =
    let 
        oldDiv = DIV
        freq = CLKSEL[TAC.bitsliced(0..1)]

    inc DIV

    if testBit(DIV, freq) and (not testBit(oldDIV, freq)) and TAC.testBit(2):
        if (TIMA == 0xFF):
            TIMA = TMA
            sendIntReq(INTTIMER)

        inc TIMA

proc incCycle*(m: int): void =
    for i in 0..<(m*4):
        tick()
        ppu.tick()

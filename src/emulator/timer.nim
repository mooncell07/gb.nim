import utils
import bitops
import types
import io

var
    cycles*: int
    oldDiv: uint16

proc clockSelect(): int =
    let freq: u2 = TAC.bitsliced(0..1)
    result = case freq
    of 0: 9
    of 1: 3
    of 2: 5
    of 3: 7

proc timerTick(): void =
    oldDiv = DIV
    inc DIV

    let freq = clockSelect()
    if testBit(DIV, freq) and (not testBit(oldDIV, freq)) and TAC.testBit(2):
        if (TIMA == 0xFF):
            sendIntReq(TIMER)
        inc TIMA

proc incCycle*(n: int): void =
    for i in 0..<(n*4):
        inc cycles
        timerTick()

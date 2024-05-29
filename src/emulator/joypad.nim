import utils
import bitops
import sdl2

var
    keyState: uint8
    P1*: uint8

proc toggleBit(num: int): void = keyState.setBit(num)
proc resetBit(num: int): void = keyState.clearBit(num)

proc unsetKey*(key: cint): void =
    case key
    of K_e: resetBit(0) # ACTION: A
    of K_q: resetBit(1) # ACTION: B
    of K_LSHIFT: resetBit(2) # ACTION: SELECT
    of K_z: resetBit(3) # ACTION: START

    of K_d: resetBit(4) # DIRECTION: RIGHT
    of K_a: resetBit(5) # DIRECTION: LEFT
    of K_w: resetBit(6) # DIRECTION: UP
    of K_s: resetBit(7) # DIRECTION: DOWN
    else: return

proc setKey*(key: cint): void =
    case key
    of K_e: toggleBit(0) # ACTION: A
    of K_q: toggleBit(1) # ACTION: B
    of K_LSHIFT: toggleBit(2) # ACTION: SELECT
    of K_z: toggleBit(3) # ACTION: START

    of K_d: toggleBit(4) # DIRECTION: RIGHT
    of K_a: toggleBit(5) # DIRECTION: LEFT
    of K_w: toggleBit(6) # DIRECTION: UP
    of K_s: toggleBit(7) # DIRECTION: DOWN
    else: return

proc getP1State*(): (uint8, bool) =
    var 
        controlBits = P1.bitsliced(4..5)
        res: uint8 = 0xCF
        fallingEdge: bool

    case controlBits.uint2
    of 0b00: discard

    of 0b01:
        let keyIndex = firstSetBit(keyState.bitsliced(0..3))
        if keyIndex > 0: 
            let finalKeyIndex = keyIndex - 1
            fallingEdge = res.testBit(finalKeyIndex)
            res.clearBit(finalKeyIndex)

    of 0b10:
        let keyIndex = firstSetBit(keyState.bitsliced(4..7))
        if keyIndex > 0: 
            let finalKeyIndex = keyIndex - 1
            fallingEdge = res.testBit(finalKeyIndex)
            res.clearBit(finalKeyIndex)

    of 0b11: res = 0xFF

    return (res, fallingEdge)

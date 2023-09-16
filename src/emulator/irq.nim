import bitops

import types
import cpu
import io

proc getIntVec(intT: IntType): uint16 {.inline.} =
    case intT
    of VBLANK: 0x40'u16
    of LCDSTAT: 0x48'u16
    of TIMER: 0x50'u16
    of SERIAL: 0x58'u16
    of JOYPAD: 0x60'u16

proc serviceIntReq*(intT: IntType): void {.inline.} =
    halted = false
    IME = false
    IMERising = false
    clearBit(IF, intT.ord)

    opCALL(getIntVec(intT), internal = false)

proc checkPendingIntReqs*(): void =
    if IF == 0:
        return

    for i in 0..4:
        if IF.testBit(i) and IE.testBit(i):
            serviceIntReq(IntType(i))

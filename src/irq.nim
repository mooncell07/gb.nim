import emulator/[types, cpu, io]
import bitops

var IVT: array[IntType, uint16] = [0x40'u16, 0x48'u16, 0x50'u16, 0x58'u16, 0x60'u16]


proc haltCheck(): void {.inline.} =
    if halted:
        halted = false

proc serviceIRQ(intT: IntType): void {.inline.} =
    halted = false
    IME = false
    IMERising = false
    clearBit(IF, intT.ord)

    jump(IVT[intT], internal = false)

proc handlePendingIRQs(): void =
    for i in 0..4:
        if IF.testBit(i) and IE.testBit(i):
            serviceIRQ(IntType(i))

proc checkPendingIRQs*(): void =
    if io.IF == 0:
        return

    # Resume execution in case HALT is sent without IME
    haltCheck()

    if IME:
        handlePendingIRQs()

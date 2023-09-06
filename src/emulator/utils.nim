import bitops

func lsb*(value: uint16): uint8 {.inline.} = (value and 0xFF).uint8
func msb*(value: uint16): uint8 {.inline.} = (value shr 8).uint8
func concat*(lo: uint8, hi: uint16): uint16 {.inline.} = (hi shl 8) or lo

func x*(opcode: uint8): uint8 {.inline.} = opcode.bitsliced(6..7)
func y*(opcode: uint8): uint8 {.inline.} = opcode.bitsliced(3..5)
func z*(opcode: uint8): uint8 {.inline.} = opcode.bitsliced(0..2)
func p*(opcode: uint8): uint8 {.inline.} = opcode.bitsliced(4..5)
func q*(opcode: uint8): uint8 {.inline.} = opcode.testbit(3).uint8

func isboundto*[T: SomeInteger](value: T, lower: T,
    upper: T): bool {.inline.} = (value >= lower) and (upper >= value)

func checkHalfCarry*(a: uint8, b: uint8): bool {.inline.} = (a and 0xF) + (b and
    0xF) >= 0x10
func checkHalfBorrow*(value: uint8): bool {.inline.} = (value and 0xF) == 0

func signed*(n: uint8): uint16 = cast[int8](n).uint16

import bitops

template lsb*(value: uint16): uint8 = (value and 0xFF).uint8
template msb*(value: uint16): uint8 = (value shr 8).uint8
template concat*(lo: uint8, hi: uint16): uint16 = (hi shl 8) or lo
template x*(opcode: uint8): uint8 = opcode.bitsliced(6..7)
template y*(opcode: uint8): uint8 = opcode.bitsliced(3..5)
template z*(opcode: uint8): uint8 = opcode.bitsliced(0..2)
template p*(opcode: uint8): uint8 = opcode.bitsliced(4..5)
template q*(opcode: uint8): uint8 = opcode.testbit(3).uint8

template isboundto*[T: SomeInteger](value: T, lower: T,
    upper: T): bool = (value >= lower) and (upper >= value)

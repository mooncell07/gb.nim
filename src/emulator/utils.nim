proc lsb*(value: uint16): uint8 = 
    return (value and 0xFF).uint8

proc msb*(value: uint16): uint8 =
    return (value shr 8).uint8

proc concat*(lo: uint8, hi: uint16): uint16 =
    return (hi shl 8) or lo

template isboundto*[T](value: T, lower: T, upper: T): bool =
    (value >= lower) and (upper >= value)

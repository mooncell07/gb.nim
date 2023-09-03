type
    R8Type* {.pure.} = enum B, C, D, E, H, L, aHL, A
    R16Type* {.pure.} = enum BC, DE, HL, SP, AF
    CCType* {.pure.} = enum ccNZ, ccZ, ccNC, ccC
    FlagType* {.pure.} = enum ftC = 4, ftH = 5, ftN = 6, ftZ = 7
type
    R8* {.pure.} = enum B, C, D, E, H, L, aHL, A
    R16* {.pure.} = enum BC, DE, HL, SP, AF
    flags* {.pure.} = enum ftC = 4, ftH = 5, ftN = 6, ftZ = 7

type
    R8Type* {.pure.} = enum B, C, D, E, H, L, aHL, A
    R16Type* {.pure.} = enum BC, DE, HL, SP, AF
    CCType* {.pure.} = enum ccNZ, ccZ, ccNC, ccC
    FlagType* {.pure.} = enum ftC = 4, ftH = 5, ftN = 6, ftZ = 7
    AluOp* {.pure.} = enum ADD, ADC, SUB, SBC, AND, XOR, OR, CP
    PrefixOp* {.pure.} = enum RLC, RRC, RL, RR, SLA, SRA, SWAP, SRL
    IntType* {.pure.} = enum INTVBLANK, INTSTAT, INTTIMER, INTSERIAL, INTJOYPAD
    LCDCType* {.pure.} = enum BGANDWINEN, OBJEN, OBJSIZE, BGTILEMAPAREA, BGANDWINTILEDATAAREA, WINEN, WINTILEMAPAREA, LCDPPUEN
    LCDSType* {.pure.} = enum PPUMODEBIT0, PPUMODEBIT1, COINCIDENCE, MODE0INT, MODE1INT, MODE2INT, LYCINT
    PPUStateType* {.pure.} = enum HBLANK, VBLANK, OAMSEARCH, PIXELTRANSFER
    TileFetcherStateType* {.pure.} = enum GETTILE, GETTILEDATALOW, GETTILEDATAHIGH, SLEEP, PUSH

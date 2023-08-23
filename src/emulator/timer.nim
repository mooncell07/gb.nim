var mcycle*: int
var tcycle*: int

proc incCycle*(n: int): void {.inline.} =
    mcycle += n; tcycle += n * 4
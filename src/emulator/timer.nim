var mcycle*: int
var tcycle*: int

proc incCycle*(n: int): void =
    mcycle += n; tcycle += n * 4
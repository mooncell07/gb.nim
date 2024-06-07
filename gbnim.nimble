# Package

version       = "0.1.0"
author        = "mooncell07"
description   = "A Nintendo Game Boy Emulator."
license       = "MIT"
srcDir        = "src"
bin           = @["main"]
binDir        = "bin"

# Dependencies

requires "nim >= 2.0.0"
requires "sdl2"
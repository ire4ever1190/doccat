import os
# Package

version       = "0.1.0"
author        = "Jake Leahy"
description   = "Provides documentation for dimscord"
license       = "MIT"
srcDir        = "src"
bin           = @["doccat", "database"]
bindir = "build"


# Dependencies

requires "nim >= 1.2.0"
# requires "dimscord >= 1.2.4"
requires "dimscord#5699596"
requires "dimscmd == 1.3.1"
requires "regex >= 0.19.0"

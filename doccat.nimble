# Package

version       = "0.1.0"
author        = "Jake Leahy"
description   = "Provides documentation for dimscord"
license       = "MIT"
srcDir        = "src"
bin           = @["doccat", "database"]
bindir        = "build"


# Dependencies

requires "nim >= 1.2.0"
requires "dimscord >= 1.4.0"
requires "dimscmd >= 1.4.0"
requires "lowdb >= 0.2.1"
requires "ponairi == 0.3.2"
requires "regex >= 0.20.1"

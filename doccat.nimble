# Package

version       = "0.1.0"
author        = "Jake Leahy"
description   = "Provides documentation for dimscord"
license       = "MIT"
srcDir        = "src"
bin           = @["doccat"]



# Dependencies

requires "nim >= 1.2.0"
requires "dimscord"
requires "regex == 0.16.2"
requires "allographer == 0.13.1"

task pull, "Pulls files from dimscord":
    if existsDir("dimscord"):
        cd("dimscord")
        exec("git pull origin master")
    else:
        exec("git clone https://github.com/krisppurg/dimscord")
        cd("dimscord")
    let latestRelease = gorge("git --git-dir dimscord/.git describe --tags", cache="test").split("-")[0]
    echo(latestRelease)
    writeFile("version", latestRelease)
    exec("git checkout " & latestRelease)
    cd("..")

task genDoc, "Generates the JSON documentation files":
    pullTask()
    cd("dimscord")
    exec("nim jsondoc --project --git.url:https://github.com/krisppurg/dimscord dimscord.nim")
    cd("..")

task genDB, "Generates the DB":
    rmFile("docs.db")
    genDocTask()
    exec("nim c -r src/database.nim")
    

task clean, "Cleans old files":
    rmDir("dimscord")
    rmFile("version")
    rmFile("db.sqlite3")
    rmFile("docs.db")

task release, "Builds a release binary":
    exec("nim c --outdir:build/ -d:danger src/doccat.nim")

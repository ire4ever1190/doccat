import os
# Package

version       = "0.1.0"
author        = "Jake Leahy"
description   = "Provides documentation for dimscord"
license       = "MIT"
srcDir        = "src"
bin           = @["doccat"]
bindir = "build"


# Dependencies

requires "nim >= 1.2.0"
# requires "dimscord >= 1.2.4"
requires "dimscmd == 1.2.2"

task pull, "Pulls files from dimscord":
    if existsDir "dimscord":
        cd "dimscord"
        exec "git pull origin master"
    else:
        exec "git clone https://github.com/krisppurg/dimscord"
        cd "dimscord"
    let latestRelease = gorge("git --git-dir dimscord/.git describe --tags", cache="").split("-")[0]
    echo latestRelease
    writeFile("version", latestRelease)
    exec "git checkout " & latestRelease
    cd thisDir()

task genDoc, "Generates the JSON documentation files":
    cd thisDir()
    mkdir "docs"
    cd "docs"
    for folder in walkDirRec(thisDir() & "/dimscord", yieldFilter = {pcDir}, relative = true):
        if not (".git" in folder):
            mkdir folder
    cd thisDir()
    exec "nim jsondoc --outdir:docs/ --project --git.url:https://github.com/krisppurg/dimscord dimscord/dimscord.nim; exit 0"

task genDB, "Generates the DB":
    rmFile("docs.db")
    exec("nim c -r src/database.nim")


task clean, "Cleans old files":
    rmDir("dimscord")
    rmDir("build")
    rmFile("version")
    rmFile("db.sqlite3")
    rmFile("docs.db")
    rmFile("src/database")

task release, "Runs all the needed tasks and builds the release binary":
    cleanTask()
    pullTask()
    genDocTask()
    genDBTask()
    exec("nimble build -d:danger doccat")
    mvFile("docs.db", "build/docs.db")

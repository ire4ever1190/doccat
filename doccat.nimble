import os
# Package

version       = "0.1.0"
author        = "Jake Leahy"
description   = "Provides documentation for dimscord"
license       = "MIT"
srcDir        = "src"
bin           = @["doccat"]



# Dependencies

requires "nim >= 1.2.0"
requires "dimscord#head"
requires "dimscmd >= 0.2.1"

proc toRelative(paths: seq[string], base: string): seq[string] =
    for path in paths:
        result &= path.relativePath(base)

proc dirTree(baseDir: string, targetDir: string): seq[string] =
    let dirs = listDirs(targetDir)
    result &= dirs.toRelative(baseDir)
    for dir in dirs:
        if not dir.contains(".git"):
            result &= dirTree(baseDir, dir).toRelative(baseDir)

task pull, "Pulls files from dimscord":
    if existsDir "dimscord":
        cd "dimscord"
        exec "git pull origin master"
    else:
        exec "git clone https://github.com/krisppurg/dimscord"
        cd "dimscord"
    let latestRelease = gorge("git --git-dir dimscord/.git describe --tags", cache="test").split("-")[0]
    echo latestRelease
    writeFile("version", latestRelease)
    exec "git checkout " & latestRelease
    cd ".."

task genDoc, "Generates the JSON documentation files":
    pullTask()
    cd thisDir()
    mkdir "docs"
    cd "docs"
    for folder in dirTree(thisDir(), thisDir() & "/dimscord"):
        mkdir(folder)
    cd thisDir()
    exec "nim jsondoc --outdir:docs/ --project --git.url:https://github.com/krisppurg/dimscord dimscord/dimscord.nim; exit 0"

task genDB, "Generates the DB":
    rmFile("docs.db")
    genDocTask()
    exec("nim c -r src/database.nim")


task clean, "Cleans old files":
    rmDir("dimscord")
    rmFile("version")
    rmFile("db.sqlite3")
    rmFile("docs.db")
    rmFile("src/database")

task release, "Runs all the needed tasks and builds the release binary":
    cleanTask()
    genDBTask()
    exec("nim c --outdir:build/ -d:danger src/doccat.nim")
    mvFile("docs.db", "build/docs.db")

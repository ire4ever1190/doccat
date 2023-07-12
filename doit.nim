import doit/api
import os
import strutils
import times
import osproc

proc dimscordDate(t: Target): Time = 
  if "dimscord/.git".dirExists:
    let (res, _) = execCmdEx "git --git-dir dimscord/.git log -1 --format=%ct"
    result = res.strip().parseBiggestInt().fromUnix()

task("pull", []):
  lastModified:
    t.dimscordDate
  if not dirExists "dimscord":
      cmd "git clone https://github.com/krisppurg/dimscord"
  cd "dimscord":
    cmd "git pull origin master"
    let latestRelease = "git describe --tags".execCmdEx().output.split("-")[0]
    echo latestRelease
    writeFile("version", latestRelease)
    cmd "git checkout " & latestRelease

target("docs", ["pull"]):
  mkdir "docs/dimscord"
  cd "docs":
    for folder in walkDirRec(pwd() / "dimscord", yieldFilter = {pcDir}, relative = true):
      if not (".git" in folder):
        mkdir folder
  cmd "nim jsondoc --outdir:docs/ -d:dimscordVoice --showNonExports --threads:off --index:on --project --git.url:https://github.com/krisppurg/dimscord dimscord/dimscord.nim"

target("docs.db", ["docs", "src/database.nim"]):
  cmd "nimble run -d:release database"

task("clean", []):
  rm("dimscord", true)
  rm("build", true)
  rm("docs", true)
  rm "src/database"
  rm "version"
  rm "docs.db"
  rm ".doit"

target("build/doccat", ["src/database.nim", "src/doccat.nim"]):
  cmd "nimble build -d:release doccat"

task("release", ["docs.db", "build/doccat"]):
  mv "docs.db", "build/docs.db"

run()

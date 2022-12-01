import doit/api
import os
import strutils
import times
import osproc

proc dimscordDate(t: Target): Time = 
  if "dimscord/.git".dirExists:
    let (res, _) = execCmdEx "git --git-dir dimscord/.git log -1 --format=%ct"
    result = res.strip().parseBiggestInt().fromUnix()

task("pull", [], lastModified = dimscordDate, handler = proc (t: Target) =
  if not dirExists "dimscord":
      cmd "git clone https://github.com/krisppurg/dimscord"
  cd "dimscord":
    cmd "git pull origin master"
    let latestRelease = "git describe --tags".execCmdEx().output.split("-")[0]
    echo latestRelease
    writeFile("version", latestRelease)
    cmd "git checkout " & latestRelease
)

target("docs", ["pull"]):
  mkdir "docs"
  cd "docs":
    for folder in walkDirRec(pwd() / "dimscord", yieldFilter = {pcDir}, relative = true):
      if not (".git" in folder):
        mkdir folder
  cmd "nim jsondoc --outdir:docs/ -d:dimscordVoice --threads:off --index:on --project --git.url:https://github.com/krisppurg/dimscord dimscord/dimscord.nim; exit 0"

target("docs.db", ["docs", "src/database.nim"]):
  cmd "nimble run -d:release database"

task("clean", []):
  rm("dimscord", true)
  rm("build", true)
  rm("src/database")
  rm "version"
  rm "docs.db"
  rm ".doit"
task("release", ["doccat", ])

run()

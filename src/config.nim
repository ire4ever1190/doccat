import macros
import json
import strformat

macro createConfigValues(): untyped =
    result = newStmtList()
    let configJson = parseJson(readFile("config.json"))
    for (key, value) in configJson.pairs():
        result.add parseStmt(&"const {key}* = \"{value.getStr()}\"")

createConfigValues()

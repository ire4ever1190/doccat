import macros
import json
import strformat

macro createConfigValues(): untyped =
    ## Creates constant global variables from all the key/value pairs in config.json
    ## Used instead of env variables since it means I don't need to mess around with having the enviroment setup correctly
    result = newStmtList()
    let configJson = parseJson(readFile("config.json"))
    for (key, value) in configJson.pairs():
        result.add parseStmt(&"const {key}* = \"{value.getStr()}\"")

createConfigValues()

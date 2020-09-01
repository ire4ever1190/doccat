import os
import json
import types
import regex
import options
import strutils
import strformat
import db_sqlite

const 
    dimscordVersion = readFile("dimscord/version")
    unnotationRe = (re"(\w)([A-Z])", "$1 $2") # sendMessage -> send Message
    
let db* = open("docs.db", "", "", "")

type DbEntry* = object
    name*: string
    url*: string
    code*: string
    description*: string

proc createTables() =
    db.exec(sql"CREATE VIRTUAL TABLE IF NOT EXISTS doc USING FTS5(name, url, code, description, searchName)")

proc unnotation(input: string): string {.inline.} = input.replace(unnotationRe[0], unnotationRe[1])

proc getEntry*(name: string): Option[DbEntry] =
    let data = db.getRow(sql"SELECT * FROM doc WHERE name = ? COLLATE NOCASE", name)
    if data != @["", "", "", "", ""]:
        return some DbEntry(
            name: data[0].split(" ").join(""),
            url: data[1],
            code: data[2],
            description: data[3]
        )
    return none(DbEntry)

proc searchEntry*(name: string): seq[DbEntry] =
    for data in db.fastRows(sql"SELECT * FROM doc WHERE doc MATCH ? ORDER BY rank", name):
        result.add DbEntry(
                    name: data[0].split(" ").join(""),
                    url: data[1],
                    code: data[2],
                    description: data[3]
                )

proc buildDocTable() =
    ## gets all the documentation that is in json repr
    ## converts the html to markdown, and the  adds to
    ## the database
    # HTML to markdown regex
    let ulRegex = re"<ul class=.simple.>\n?([\W\s\w]+)\n?<\/ul>" # Start of list
    let liRegex = re"<li>(.*)</li>" # List item
    let singleLineCodeRegex = re"<tt class=.docutils literal.><span class=.pre.>([^<]+)<\/span><\/tt>" # Code example html
    let aRegex = re"<a class=.[\w ]+. href=.([^<]+).>([^<]+)<\/a>" # Link
    let pRegex = re"<p>([\W\s\w]+)</p>" # paragraph
    
    for kind, path in walkDir("dimscord/dimscord"):
        if path.endsWith(".json"):
            let json = parseJson(readFile(path))
            var docObj = json.to(JsonDoc)
            for entry in docObj.entries:
                if entry.description.isSome:
                    var description = entry.description.unsafeAddr
                    description[] = some description[].get()
                            .replace(ulRegex, "$1")
                            .replace(liRegex, "\n - $1")
                            .replace(singleLineCodeRegex, "`$1`")
                            .replace("&quot;", "\"") 
                            .replace(aRegex, "[$2]($1)")
                            .replace(pRegex, "$1")
                var entryFile = entry.file.unsafeAddr
                entryFile[] = some(path.replace("dimscord/dimscord/", "dimscord/").replace(".json", ".nim"))
                db.exec(sql"INSERT INTO doc VALUES (?, ?, ?, ?, ?)",
                    entry.name,
                    fmt"https://github.com/krisppurg/dimscord/blob/{dimscordVersion}/{entry.file.get()}#L{entry.line}",
                    entry.code,
                    if entry.description.isSome: entry.description.get() else: "",
                    entry.name.unnotation() # Used so the user can search by name
                )
                
when isMainModule:
    createTables()
    buildDocTable()
    db.close()

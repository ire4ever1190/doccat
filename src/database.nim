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
            name: data[0].replace(" ", ""), # Remove all the spaces
            url: data[1],
            code: data[2],
            description: data[3]
        )
    return none(DbEntry)

proc searchEntry*(name: string): seq[DbEntry] =
    ## Searches through the database to find something that matches the name
    for data in db.fastRows(sql"SELECT * FROM doc WHERE doc MATCH ? ORDER BY rank", name):
        result.add DbEntry(
                    name: data[0].replace(" ", ""),
                    url: data[1],
                    code: data[2],
                    description: data[3]
                )

proc getFiles(dir: string): seq[string] =
    for path in walkDirRec(dir):
        result &= path
    echo result

proc buildDocTable() =
    ## gets all the documentation that is in json repr
    ## converts the html to markdown, and the  adds to
    ## the database

    let # All the regex to find HTML tags
        ulRegex = re"<ul class=.simple.>\n?([\W\s\w]+)\n?<\/ul>" # Start of list
        liRegex = re"<li>(.*)</li>" # List item
        singleLineCodeRegex = re"<tt class=.docutils literal.><span class=.pre.>([^<]+)<\/span><\/tt>" # Code example html
        aRegex = re"<a class=.[\w ]+. href=.([^<]+).>([^<]+)<\/a>" # Link
        pRegex = re"<p>([\W\s\w]+)</p>" # paragraph
        strongRegex = re"<strong>([\W\s\w]+)</strong>" # Strong (bolded text)
    for path in getFiles("docs"):
        echo path
        if path.endsWith(".json"):
            let json = parseJson(readFile(path))
            var docObj = json.to(JsonDoc)
            for entry in docObj.entries:
                if entry.description.isSome:
                    var description = entry.description.unsafeAddr
                    description[] = some description[].get() # Use the previous defined regex to replace html with markdown equivalant
                            .replace(ulRegex, "$1")
                            .replace(liRegex, "\n - $1")
                            .replace(singleLineCodeRegex, "`$1`")
                            .replace("&quot;", "\"")
                            .replace(aRegex, "[$2]($1)")
                            .replace(pRegex, "$1")
                            .replace(strongRegex, "**$1**")
                var entryFile = entry.file.unsafeAddr
                entryFile[] = some(path.replace("docs/dimscord/", "dimscord/").replace(".json", ".nim"))
                db.exec(sql"INSERT INTO doc VALUES (?, ?, ?, ?, ?)",
                    entry.name,
                    fmt"https://github.com/krisppurg/dimscord/blob/{dimscordVersion}/{entry.file.get()}#L{entry.line}",
                    entry.code,
                    if entry.description.isSome: entry.description.get() else: "",
                    entry.name.unnotation() # Used so the user can search by name
                )

when isMainModule:
    echo("Building docs with " & dimscordVersion)
    createTables()
    buildDocTable()
    db.close()

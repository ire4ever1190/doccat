import os
import json
import types
import regex
import options
import strutils
import strformat
import strtabs
import ponairi

const
  dimscordVersion = readFile("dimscord/version")
  unnotationRe = (re"(\w)([A-Z])", "$1 $2") # sendMessage -> send Message

let db* = newConn("docs.db")

type DbEntry* = object
  name*: string
  url*: string
  code*: string
  description*: string
  searchName*: string

proc createTables() =
  db.exec(sql"DROP TABLE IF EXISTS DbEntry")
  db.exec(sql"CREATE VIRTUAL TABLE IF NOT EXISTS DbEntry USING FTS5(name, url, code, description, searchName)")

proc unnotation(input: string): string {.inline.} = input.replace(unnotationRe[0], unnotationRe[1])

proc getEntry*(name: string): seq[DbEntry] =
  return db.find(seq[DbEntry], sql"SELECT * FROM DbEntry WHERE name = ? COLLATE NOCASE", name)

proc searchEntry*(name: string): seq[DbEntry] =
  ## Searches through the database to find something that matches the name
  echo "Searching for ", name
  result = db.find(seq[DbEntry], sql"SELECT * FROM DbEntry WHERE DbEntry MATCH ? ORDER BY rank", name)

proc buildDocTable() =
  ## gets all the documentation that is in json repr
  ## converts the html to markdown, and the  adds to
  ## the database

  let # All the regex to find HTML tags
    ulRegex = re"<ul class=.simple.>\n?([\W\s\w]+)\n?<\/ul>" # Start of list
    liRegex = re"<li>(.*)</li>" # List item
    identRegex = re"<span class=.Identifier.>([^<]+)</span>"
    singleLineCodeRegex = re"<tt class=.docutils literal.><span class=.pre.>([^<]+)<\/span><\/tt>" # Code example html
    aRegex = re"<a class=.[\w ]+. href=.([^<]+).>([^<]+)<\/a>" # Link
    pRegex = re"<p>([\W\s\w]+)</p>" # paragraph
    strongRegex = re"<strong>([\W\s\w]+)</strong>" # Strong (bolded text)
  # First load the index file so we can get proper links for everything
  let json = parseFile("docs/theindex.json")

  db.startTransaction()
  for path in walkDirRec("docs"):
    if path.endsWith(".json") and not path.endsWith("theindex.json"):
      let json = parseFile(path)
      var docObj = json.to(JsonDoc)
      for entry in docObj.entries.mitems:
        if entry.description.isSome:
          entry.description = some entry.description.unsafeGet() # Use the previous defined regex to replace html with markdown equivalant
            .replace(ulRegex, "$1")
            .replace(identRegex, "$1")
            .replace(liRegex, "\n - $1")
            .replace(singleLineCodeRegex, "`$1`")
            .replace("&quot;", "\"")
            .replace(aRegex, "[$2]($1)")
            .replace(pRegex, "$1")
            .replace(strongRegex, "**$1**")
        var entryFile = entry.file.unsafeAddr
        entryFile[] = some(path.replace("docs/dimscord/", "dimscord/").replace(".json", ".nim"))
        db.insert DbEntry(
            name: entry.name,
            url: fmt"https://github.com/krisppurg/dimscord/blob/{dimscordVersion}/{entry.file.get()}#L{entry.line}",
            code: entry.code,
            description: if entry.description.isSome: entry.description.get() else: "",
            searchName: entry.name.unnotation()
        )
  db.commit()

when isMainModule:
    echo("Building docs with " & dimscordVersion)
    createTables()
    buildDocTable()
    db.close()

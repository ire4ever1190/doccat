import dimscord
import asyncdispatch
import config
import strutils
import os
import json
import types
import regex
import tables
import options
import strformat

proc buildDocTable(): Table[string, Entry] =
    let ulRegex = re"<ul class=.simple.>(.*)\n?<\/ul>" # Start of list
    let liRegex = re"<li>(.*)</li>" # List item
    let singleLineCodeRegex = re"<tt class=.docutils literal.><span class=.pre.>([^<]+)<\/span><\/tt>" # Code example html
    let aRegex = re"<a class=.[\w ]+. href=.([^<]+).>[^<]+<\/a>"
    for kind, path in walkDir("dimscord/dimscord"):
        if path.endsWith(".json"):
            echo(path)
            let json = parseJson(readFile(path))
            var docObj = json.to(JsonDoc)
            for entry in docObj.entries:
                # If someone knows a better way, please tell
                if entry.name == "editGuild":
                    echo(entry.description)
                result[entry.name.toLower()] = Entry(
                    line: entry.line,
                    col: entry.col,
                    code: entry.code.unindent(),
                    `type`: entry.`type`,
                    name: entry.name,
                    file: some(path.replace("dimscord/dimscord/", "dimscord/").replace(".json", ".nim")),
                    description: if entry.description.isSome: some entry.description.get()
                                            .replace(ulRegex, "$1")
                                            .replace(liRegex, "\n - $1")
                                            .replace(singleLineCodeRegex, "`$1`")
                                            .replace("&quot;", "\"") 
                                            .replace(aRegex, "$1") else: none string
                                            
                )

when defined(release):
    const token = TOKEN
else:
    when declared(TESTING_TOKEN):
        const token = TESTING_TOKEN
    else:
        const token = TOKEN
        
const docTable = buildDocTable()
let discord = newDiscordClient(token)

proc reply(m: Message, content: string) {.async.} =
    discard await discord.api.sendMessage(m.channelId, content)

proc reply(m: Message, embed: Option[Embed]) {.async.} =
    discard await discord.api.sendMessage(m.channelId, embed = embed)

discord.events.message_create = proc (s: Shard, m: Message) {.async.} =
    if m.author.bot: return
    let args = m.content.split(" ")
    if args.len() == 0: return
    if args[0] == "doc":
        if args.len() == 1:
            await m.reply("You have not specified a name")
        else:
            let name = args[1].toLower()
            if docTable.hasKey(name):
                let entry = docTable[name]
                    
                if entry.description.isSome:
                    var description = entry.description.get()
                    description &= "\n```nim\n" & entry.code & "```"
                    await m.reply(some Embed(
                        title: some entry.name,
                        description: some description,
                        url: some fmt"https://github.com/krisppurg/dimscord/blob/{DIMSCORD_VERSION}/{entry.file.get()}#L" & $entry.line
                    ))
                else:
                    await m.reply("```nim\n" & entry.code & "```")
            else:
                await m.reply("I'm sorry, but there is nothing with this name")

discord.events.on_ready = proc (s: Shard, r: Ready) {.async.} =
    echo "Ready as " & $r.user
    echo genInviteLink(r.user.id)
    
waitFor discord.startSession()

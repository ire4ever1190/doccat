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
    # HTML to markdown regex
    let ulRegex = re"<ul class=.simple.>\n?([\W\s\w]+)\n?<\/ul>" # Start of list
    let liRegex = re"<li>(.*)</li>" # List item
    let singleLineCodeRegex = re"<tt class=.docutils literal.><span class=.pre.>([^<]+)<\/span><\/tt>" # Code example html
    let aRegex = re"<a class=.[\w ]+. href=.([^<]+).>([^<]+)<\/a>"
    let pRegex = re"<p>([\W\s\w]+)</p>"
    
    for kind, path in walkDir("dimscord/dimscord"):
        if path.endsWith(".json"):
            echo(path)
            let json = parseJson(readFile(path))
            var docObj = json.to(JsonDoc)
            for entry in docObj.entries:
                # If someone knows a better way, please tell, deep copy or something isn't it?
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

                result[entry.name.toLower()] = entry

when defined(release):
    const token = TOKEN
else:
    when declared(TESTING_TOKEN):
        const token = TESTING_TOKEN
    else:
        const token = TOKEN
        
const docTable = buildDocTable()
let discord = newDiscordClient(token)

proc reply(m: Message, content: string) {.async, inline.} =
    discard await discord.api.sendMessage(m.channelId, content)

proc trunc(s: string, length: int): string =
    if s.len() > length:
        return s[0..<length] & "(click link below to see full version)"
    return s
    
proc reply(m: Message, embed: Option[Embed]) {.async, inline.} =
    discard await discord.api.sendMessage(m.channelId, embed = embed)

discord.events.message_create = proc (s: Shard, m: Message) {.async.} =
    # try:
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
                        let description = entry.description.get()
                        let embed = some Embed(
                            title: some entry.name,
                            description: entry.description,
                            url: some fmt"https://github.com/krisppurg/dimscord/blob/{DIMSCORD_VERSION}/{entry.file.get()}#L{entry.line}"
                        )
                        discard await discord.api.sendMessage(m.channelId, &"```nim\n{entry.code.trunc(1500)}```", embed = embed)

                    else:
                        await m.reply(&"```nim\n{entry.code.trunc(1500)}```")
                else:
                    await m.reply("I'm sorry, but there is nothing with this name")
    # except:
        # echo("werror")
discord.events.on_ready = proc (s: Shard, r: Ready) {.async.} =
    echo "Ready as " & $r.user
    echo genInviteLink(r.user.id)
    
waitFor discord.startSession()

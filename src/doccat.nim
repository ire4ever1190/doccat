import math
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
import wait

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
        
const 
    docTable = buildDocTable()
    dimscordVersion = readFile("dimscord/version")
    forwardEmoji = "➡️"
    backEmoji = "⬅️"
let discord = newDiscordClient(token)

proc reply(m: Message, content: string, messageEmbed: Option[Embed] = none(Embed)): Future[Message] {.async.}=
    return await discord.api.sendMessage(m.channelId, content, embed = messageEmbed)

proc trunc(s: string, length: int, page: int = 0): string =
    # TODO paginiation
    if s.len() > length:
        var wordEnd = length * (page + 1)
        if wordEnd > s.len(): wordEnd = s.len()
        return s[(page * length) + (if page > 0: -5 else: 0)..<wordEnd]
    return s    



discord.events.onDispatch = proc (s: Shard, evt: string, data: JsonNode) {.async.} =
    if evt == "MESSAGE_REACTION_ADD":
        # If it is an emoji then check if a message is waiting on a reaction
        if waits.hasKey(data["message_id"].str):
            let wait = waits[data["message_id"].str]
            wait.complete(data["emoji"]["name"].str)
            waits.del(data["message_id"].str)

discord.events.message_create = proc (s: Shard, m: Message) {.async.} =
    if m.author.bot and not m.webhookId.isSome(): return
    let args = m.content.split(" ")
    if args.len() == 0: return
    # TODO search
    if unlikely(args[0] == "doc"):
        if args.len() == 1:
            discard m.reply("You have not specified a name")
        else:
            let name = args[1].toLower()
            if name == "help":
                discard m.reply("to use, just send `doc` followed by something in the library e.g. `doc sendMessage`\nFor big things like `doc Events` you can tack a number onto the end to get more `doc Events 2`")
                return
            var page = 0
            
            if args.len() >= 3:
                page = abs(parseInt(args[2]) - 1)
            if docTable.hasKey(name):
                let entry = docTable[name]
                var maxPage = int ceil(len(entry.code)/1500)
                var 
                    responseMessage: Message
                echo(maxPage, page)
                if entry.description.isSome:
                    let description = entry.description.get()
                    let embed = some Embed(
                    title: some entry.name,
                        description: entry.description,
                        url: some fmt"https://github.com/krisppurg/dimscord/blob/{dimscordVersion}/{entry.file.get()}#L{entry.line}"
                    )
                    responseMessage = await m.reply(&"```nim\n{entry.code.trunc(1500, page)}```", embed)
                else:
                    responseMessage = await m.reply(&"```nim\n{entry.code.trunc(1500, page)}```")
                if entry.code.len > 1500:
                    while true:
                        if page > 0:
                            await discord.api.addMessageReaction(m.channelId, responseMessage.id, backEmoji)
                        if page + 1 < maxPage:
                            await discord.api.addMessageReaction(m.channelId, responseMessage.id, forwardEmoji)
                        let reaction = await responseMessage.waitForReaction()
                        if reaction == backEmoji:
                            if page != 0:
                                page -= 1
                        elif reaction == forwardEmoji:
                            if page + 1 < maxPage:
                                page += 1
                        elif reaction.isEmptyOrWhiteSpace: # Emojis make it blank
                            echo("timed out")
                            return
                        if entry.description.isSome:
                            let description = entry.description.get()
                            let embed = some Embed(
                            title: some entry.name,
                                description: entry.description,
                                url: some fmt"https://github.com/krisppurg/dimscord/blob/{dimscordVersion}/{entry.file.get()}#L{entry.line}"
                            )
                            discard await discord.api.editMessage(responseMessage.channelId, responseMessage.id, &"```nim\n{entry.code.trunc(1500, page)}```", embed = embed)                                
                        else:
                            discard await discord.api.editMessage(responseMessage.channelId, responseMessage.id, &"```nim\n{entry.code.trunc(1500, page)}```")
                        try:
                            await discord.api.deleteAllMessageReactions(m.channelId, responseMessage.id)
                        except:
                            echo("no permission")
                            # discard await m.reply("I don't have permission to manage messages")
            else:
                discard m.reply("I'm sorry, but there is nothing with this name")
discord.events.on_ready = proc (s: Shard, r: Ready) {.async.} =
    echo "Ready as " & $r.user
    
waitFor discord.startSession()

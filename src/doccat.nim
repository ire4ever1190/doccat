import segfaults
import math
import dimscord
import asyncdispatch
import config
import strutils
import os
import json
import tables
import options
import strformat
import wait
import database

when defined(release):
    const token = TOKEN
else:
    when declared(TESTING_TOKEN):
        const token = TESTING_TOKEN
    else:
        const token = TOKEN
        
const 
    forwardEmoji = "➡️"
    backEmoji = "⬅️"

let discord = newDiscordClient(token)

proc reply(m: Message, content: string, messageEmbed: Option[Embed] = none(Embed)): Future[Message] {.async.}=
    return await discord.api.sendMessage(m.channelId, content, embed = messageEmbed)

proc trunc(s: string, length: int, page: int = 0): string =
    if s.len() > length:
        var wordEnd = length * (page + 1) # Make the end be the specified length but n + 1 pages in
        if wordEnd > s.len(): # If the end is bigger than the string
            wordEnd = s.len() # Make the end be the length of the string
        # Return the string data between the n pages in and n + 1 pages in
        # If there is still some remaining text then add '...'
        result =  s[(page * length) + (if page > 0: -5 else: 0)..<wordEnd] & (if wordEnd < s.len(): "..." else: "")  
        if wordEnd < s.len():
            result &= ""
    else:
        result = s

discord.events.onDispatch = proc (s: Shard, evt: string, data: JsonNode) {.async.} =
    if evt == "MESSAGE_REACTION_ADD":
        # If it is an emoji then check if a message is waiting on a reaction
        if waits.hasKey(data["message_id"].str):
            let wait = waits[data["message_id"].str]
            wait.complete(data["emoji"]["name"].str)
            waits.del(data["message_id"].str)

discord.events.message_create = proc (s: Shard, m: Message) {.async.} =
    if m.author.bot and not m.webhookId.isSome(): return
    let args = m.content.toLowerAscii().split(" ")
    if args.len() == 0: return
    if unlikely(args[0] == "doc"):
        if args.len() == 1:
            discard m.reply("You have not specified a name")
        else:
            let name = args[1]
            if name == "help":
                discard m.reply("to use, just send `doc` followed by something in the library e.g. `doc sendMessage`\nFor big things like `doc Events` you can tack a number onto the end to get more `doc Events 2`")
                return
            elif name == "search" and args.len() >= 3:
                var msg = ""
                for entry in searchEntry(args[2..<len(args)].join(" ")):
                    msg &= entry.name & "\n"
                discard m.reply(msg)
                return
            var page = 0
            let dbEntry = getEntry(name)
            if dbEntry.isSome:
                let
                    entry = dbEntry.get() 
                    maxPage = int ceil(len(entry.code)/1500)
                var embed = some Embed(
                        title: some entry.name,
                        description: some entry.description,
                        url: some entry.url
                    )
                        
                var responseMessage = await m.reply(&"```nim\n{entry.code.trunc(1500, page)}```", embed)
                # 
                # Below this is the handling for the page turning
                #
                if entry.code.len > 1500:
                    while true:
                        if page > 0:
                            await discord.api.addMessageReaction(m.channelId, responseMessage.id, backEmoji)
                        if page + 1 < maxPage:
                            await discord.api.addMessageReaction(m.channelId, responseMessage.id, forwardEmoji)
                        let reaction = await responseMessage.waitForReaction()
                        if reaction == backEmoji:
                            if page != 0: # Check that you are not on the first page
                                page -= 1

                        elif reaction == forwardEmoji:
                            if page + 1 < maxPage: # Check that you are not on the last page
                                page += 1

                        elif reaction.isEmptyOrWhiteSpace: # Emojis make it blank
                            return
                            
                        embed = some Embed(
                                title: some entry.name,
                                description: some entry.description,
                                url: some entry.url
                            )                        
                        discard await discord.api.editMessage(responseMessage.channelId, responseMessage.id, &"```nim\n{entry.code.trunc(1500, page)}```", embed = embed)
                        try:
                            await discord.api.deleteAllMessageReactions(m.channelId, responseMessage.id)
                        except:
                            echo("no permission")
            else:
                discard m.reply("I'm sorry, but there is nothing with this name")
discord.events.on_ready = proc (s: Shard, r: Ready) {.async.} =
    echo "Ready as " & $r.user
    
const intents = {
    giGuildMessages,
    giGuildMessageReactions
}
waitFor discord.startSession(guildSubscriptions = false, intents)

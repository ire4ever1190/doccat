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
import dimscmd
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
var cmd = discord.newHandler()

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

cmd.addChat("docsearch") do (input: seq[string], m: Message):
    var msg = ""
    var entries = input.join(" ").searchEntry()
    if entries.len > 0:
      # Only grab first 10 if too many
      const limit = 25
      if entries.len > limit:
        msg &= "(results have be truncated)\n"
        entries = entries[0..limit - 1]
      for entry in entries:
          msg &= entry.name & "\n"
      discard await m.reply(msg)
    else:
      discard await m.reply("Sorry, no results found")

cmd.addChat("help") do (): discard # Don't respond to someone saying just help

cmd.addChat("doc") do (name: string, m: Message):
    if name == "help":
        discard m.reply("to use, just send `doc` followed by something in the library e.g. `doc sendMessage`\nFor big things like `doc Events` you can switch between the pages using the emojis\nYou can search using `docsearch` followed by what you want to search for")

    else: # They have specified something to get the documentation for
        let dbEntry = getEntry(name)
        if dbEntry.isSome:
            let
                entry = dbEntry.get()
                maxPage = int ceil(len(entry.code)/1500)

            var
                page = 0
                embed = some Embed(
                    title: some entry.name,
                    description: some entry.description,
                    url: some entry.url
                )
                responseMessage = await m.reply(&"```nim\n{entry.code.trunc(1500, page)}```", embed)

            if entry.code.len > 1500:
                while true:
                    # Only add the emojis if the user is actually able to switch pages
                    if page > 0:
                        await discord.api.addMessageReaction(m.channelId, responseMessage.id, backEmoji)
                    if page + 1 < maxPage:
                        await discord.api.addMessageReaction(m.channelId, responseMessage.id, forwardEmoji)
                    # Wait for the user to respond with an arrow emoji.
                    # Then change the page depending on that
                    let reaction = await responseMessage.waitForReaction()
                    case reaction
                        of backEmoji:
                            if page != 0: page -= 1 # Check that you are not on the first page. Then go back one page
                        of forwardEmoji:
                            if page + 1 < maxPage: page += 1 # Check that you are not on the last page. THen go forward one page
                        of "": # Reaction is blank if it has timed out
                            break

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

discord.events.message_create = proc (s: Shard, m: Message) {.async.} =
    if m.author.bot and not m.webhookId.isSome(): return
    discard await cmd.handleMessage("", m)

discord.events.on_ready = proc (s: Shard, r: Ready) {.async.} =
    echo "Ready as " & $r.user

const intents = {
    giGuildMessages,
    giGuildMessageReactions
}
waitFor discord.startSession(guildSubscriptions = false, intents)

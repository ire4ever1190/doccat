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
import dimscord/restapi/requester

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
    maxMsgSize = 1500 # Limit is 2000 but this seems more sane for longer messages

let discord = newDiscordClient(token)
var cmd = discord.newHandler()

proc reply(m: Message, content: string, embeds = newSeq[Embed]()): Future[Message] {.async.}=
    return await discord.api.sendMessage(m.channelId, content, embeds = embeds)

proc trunc(s: string, length: int, page: int = 0): string =
    if s.len() > length:
        var wordEnd = length * (page + 1) # Make the end be the specified length but n + 1 pages in
        if wordEnd > s.len(): # If the end is bigger than the string
            wordEnd = s.len() # Make the end be the length of the string
        # Return the string data between the n pages in and n + 1 pages in
        # If there is still some remaining text then add '...'
        result =  s[(page * length)..<wordEnd]
        if wordEnd < s.len():
          result &= "..."
    else:
        result = s

proc editMessageNew*(api: RestApi, channel_id, message_id: string;
        content = ""; tts = false; flags = none(int);
        embeds = newSeq[Embed](), components = newSeq[MessageComponent]()): Future[Message] {.async.} =
    ## Edits a discord message.
    assert content.len <= 2000
    let payload = %*{
        "content": content,
        "tts": tts,
        "flags": %flags
    }

    if embeds.len > 0:
        payload["embeds"] = %embeds

    if components.len > 0:
        payload["components"] = newJArray()
        for component in components:
            payload["components"] &= %%*component

    result = (await api.request(
        "PATCH",
        endpointChannelMessages(channel_id, message_id),
        $payload
    )).newMessage

func codeBlock(code, lang: string = "nim"): string {.inline.} =
  result = "```"
  result &= lang
  result &= "\n"
  result &= code
  result &= "```"

proc sendBigMessage(channelID: string, msg: string, embeds = newSeq[Embed](), isCode = false) {.async.} =
  ## Used when you are unsure of the size of msg.
  ## If the message is bigger than the max message size then it adds buttons to flick between pages
  if msg.len <= maxMsgSize:
    # Small enough to send in one go
    discard await discord.api.sendMessage(channelID, if isCode: codeBlock(msg) else: msg, embeds = embeds)
  else:
    var page = 0
    template getMsg: string =
      ## Get message with proper formatting (e.g. in a codeblock) and truncated to current page
      block:
        let truncatedMsg = msg.trunc(maxMsgSize, page)
        if isCode:
          codeBlock(truncatedMsg)
        else:
          truncatedMsg
    let
      maxPage = int ceil(msg.len/maxMsgSize)
      m = await discord.api.sendMessage(channelID, getMsg(), embeds = embeds)
    while true:
      var row = newActionRow()
      let
        canGoNext = page + 1 < maxPage
        canGoBack = page > 0
      if canGoBack:
        row &= newButton(label="back", idOrUrl="back")
      if canGoNext:
        row &= newButton(label="next", idOrUrl="next")
      let actionPressed = waitPress(row.components, m.id)
      discard await discord.api.editMessageNew(channelID, m.id, getMsg(), embeds = embeds, components = @[row])
      # Now we wait for it to be pressed
      let action = await actionPressed
      echo action
      if action == "next" and canGoNext:
        inc page
      elif action == "back" and canGoBack:
        dec page
      else:
        break

cmd.addChat("docsearch") do (input: seq[string], m: Message):
    var msg = ""
    let entries = input.join(" ").searchEntry()
    if entries.len > 0:
      # Only grab first 10 if too many
      for entry in entries:
          msg &= entry.name & "\n"
      await sendBigMessage(m.channelID, msg)
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
                embed = Embed(
                    title: some entry.name,
                    description: some entry.description,
                    url: some entry.url
                )
            await sendBigMessage(m.channelID, entry.code, @[embed], true)

        else:
            discard m.reply("I'm sorry, but there is nothing with this name")

discord.events.message_create = proc (s: Shard, m: Message) {.async.} =
    if m.author.bot and not m.webhookId.isSome(): return
    discard await cmd.handleMessage("", m)

discord.events.on_ready = proc (s: Shard, r: Ready) {.async.} =
    echo "Ready as " & $r.user

proc interactionCreate(s: Shard, i: Interaction) {.event(discord).} =
  echo "Got interaction"
  if i.data.isSome and i.message.isSome:
    let
      data = i.data.get().customID
      msgID = i.message.get().id
    if msgID in buttonWaits:
      buttonWaits[msgID].complete(data)
      buttonWaits.del msgID
    try:
      await discord.api.createInteractionResponse(i.id, i.token, InteractionResponse(kind: irtDeferredUpdateMessage))
    except: # Sometimes an error occurs somehow
      echo "how?"

const intents = {
    giGuildMessages,
    giGuildMessageReactions
}
waitFor discord.startSession(guildSubscriptions = false, intents)

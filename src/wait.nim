import asyncdispatch
import tables
import dimscord

var buttonWaits*: Table[string, Future[string]]

proc waitPress*(buttons: seq[MessageComponent], msgID: string): Future[string] =
  ## Waits for a button from `buttons` to be pressed.
  ## Returns custom ID of button that was pressed (empty if it timed out)
  result = newFuture[string](fromProc="waitPress")
  var timeoutFuture = result.withTimeout(60 * 5 * 1000) # Wait 5 mins max for button presses
  buttonWaits[msgID] = result
  timeoutFuture.addCallback() do (completed: Future[bool]):
    {.gcsafe.}: # This is safe I swear
      if not completed.read and msgID in buttonWaits:
        buttonWaits[msgID].complete("")
        buttonWaits.del(msgID)

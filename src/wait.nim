import asyncdispatch
import tables
from dimscord import Message


# Holds all the waits
var waits*: Table[string, Future[string]]

proc waitForReaction*(m: Message): Future[string] =
    result = newFuture[string]()
    var timeoutFuture = withTimeout(result, 60 * 5 * 1000) # Waits 5 minutes
    timeoutFuture.addCallback( # Wait 5 minutes for it to complete
        proc(completed: Future[bool]) {.gcsafe.} = # It isn't GC safe but it makes the compiler shut up
            {.gcsafe.}: # I really hope this doesn't lead to race conditions
                if not completed.read:
                    waits[m.id].complete("")
                    waits.del(m.id)
            
    ) # Wait 5 minutes
    
    # Waits for a certain emoji to be responded
    waits[m.id] = result
    return result
                                                                                

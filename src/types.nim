import options
type
    Argument* = object
        `type`*: string
        name*: string
        default*: Option[string]

    Signature* = object
        arguments*: Option[seq[Argument]]
    
    Entry* = object
        ## Might use more of this in the future
        line*: int
        # col*: int
        code*: string
        # `type`*: string
        name*: string
        description*: Option[string]
        file*: Option[string]
        # signature*: Option[Signature]
        
    JsonDoc* = object
        isProcessed*: Option[bool]
        orig*: string
        nimble*: string
        moduleDescription*: string
        entries*: seq[Entry]        

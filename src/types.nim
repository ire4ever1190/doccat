import options
type
    Argument* = object
        `type`*: string
        name*: string
        default*: Option[string]

    Signature* = object
        arguments*: Option[seq[Argument]]
    
    Entry* = object
        line*: int
        col*: int
        code*: string
        `type`*: string
        name*: string
        description*: Option[string]
        file*: Option[string]
        signature*: Option[Signature]
        
    JsonDoc* = object
        orig*: string
        nimble*: string
        moduleDescription*: string
        entries*: seq[Entry]        

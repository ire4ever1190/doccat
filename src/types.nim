import options
type
    Entry* = object
        line*: int
        col*: int
        code*: string
        `type`*: string
        name*: string
        description*: Option[string]
        
    JsonDoc* = ref object
        orig*: string
        nimble*: string
        moduleDescription*: string
        entries*: seq[Entry]        

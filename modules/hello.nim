import json, asyncdispatch, strutils

import telegram
import module as _

module:
    help hello: "Just say hello."
    cmd hello:
        reply "Hello, @" & msg["from"]["username"].str

    help echo: "/echo arguments... - Echo the arguments"
    cmd echo:
        expect 1
        reply args.join(" ")

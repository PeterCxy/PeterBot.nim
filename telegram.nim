import httpclient, json, asyncdispatch, macros, strutils

import loader

# Telegram Bot API interface
const BASE_URL = "https://api.telegram.org/bot" & cfg_token
const METHODS = @[
    "getMe",
    "getUpdates",
    "sendMessage"
]
const METHOD_ARGUMENTS = {
    "getMe": @[],
    "getUpdates": @["timeout", "offset", "limit"],
    "sendMessage": @["chat_id", "text", "parse_mode", "reply_to_message_id"]
}

var ME* = "Who"

proc telegramMethod*(name: string, d: MultipartData):
    Future[JsonNode] {.async} =
    var data = d

    # Add a placeholder (to avoid errors when data is empty)
    data["placeholder"] = "aaa"

    let url = BASE_URL & "/" & name

    let resp = await newAsyncHttpClient().post(url, multipart=data)
    let res = parseJson(resp.body)

    if res["ok"].bval:
        return res["result"]
    else:
        return nil

# Convinent macro to generate Telegram API methods
macro generateMethods(): stmt {.immediate.} =
    var source = ""
    
    for m in METHODS:
        source &= """
proc $1*(data: MultipartData): Future[JsonNode] {.async} =
    return await telegramMethod("$1", data)
""" % m

    # Methods with named arguments
    for entry in METHOD_ARGUMENTS:
        var (k, v) = entry

        var args = ""
        for a in v:
            args &= a & ":string = nil,"
        args = args[0..(args.len - 2)]

        source &= """
proc $1*($2): Future[JsonNode] {.async} =
    var form = newMultiPartData()
""" % [k, args]

        for a in v:
            source &= """
    if $1 != nil:
        form["$1"] = $1
""" % a

        source &= """
    return await $1(form)
""" % k

    return parseStmt source

generateMethods()

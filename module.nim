# Base utilities for the bot's modules
import tables, json, asyncdispatch, logging, macros, strutils, hashes

import telegram

type Processor = proc(msg: JsonNode, args: seq[string], cmd: string): Future[void]
var COMMANDS = initTable[string, Processor]()
var HELPS = initTable[string, string]()
var readers = initTable[tuple[chat: int64, user: int64], Future[JsonNode]]()

proc hash(x: tuple[chat: int64, user: int64]): Hash =
  result = x.chat.hash !& x.user.hash

proc addCommand*(cmd: string, f: Processor) =
  COMMANDS[cmd] = f

proc callCommand*(cmd: string, msg: JsonNode, args: seq[string]) {.async} =
  if not COMMANDS.hasKey(cmd):
    return

  debug "Calling " & cmd
  asyncCheck COMMANDS[cmd](msg, args, cmd)

proc addHelp*(cmd: string, help: string) =
  HELPS[cmd] = help

# Wait for and read the next message from the user
# Returns a Future object which can be awaited.
proc cancelReader*(msg: JsonNode)
proc readMsg*(msg: JsonNode): Future[JsonNode] =
  cancelReader msg
  var key = (msg["chat"]["id"].num, msg["from"]["id"].num)
  result = newFuture[JsonNode]()
  readers[key] = result

proc cancelReader*(msg: JsonNode) =
  var key = (msg["chat"]["id"].num, msg["from"]["id"].num)
  if readers.hasKey(key):
    debug "Cancelling future " & $key
    readers[key].complete(newJNull()) # Complete the last future with a null object
    readers.del(key)

proc handleNonCommand*(msg: JsonNode) =
  var key = (msg["chat"]["id"].num, msg["from"]["id"].num)
  if readers.hasKey(key):
    debug "Future completed " & $key
    readers[key].complete(msg)
    readers.del(key)

macro module*(body: stmt): stmt {.immediate.} =
  result = newStmtList()
  for i in 0.. <body.len:
    case body[i].kind
    of nnkCommand:
      if $body[i][0].ident == "cmd":
        let name = $body[i][1].ident
        var p =  parseStmt("proc cmd_$1(msg: JsonNode, args: seq[string], cmd: string) {.async} = placeholder" % name)[0]
        p.body = body[i][2]
        p.body.insert 0, parseStmt("var res: JsonNode = nil")
        p.body.insert 0, parseStmt("var msg = msg")

        # Add convenient methods
        proc preProcess(b: NimNode) =
          for j in 0.. <b.len:
            case b[j].kind
            of nnkCommand:
              if b[j][0].ident.`$` == "reply":
                # Convenient "reply" command
                let expr = b[j][1]
                b[j] = parseStmt("""
res = await sendMessage(text = "placeholder",
  chat_id = msg["chat"]["id"].num.`$`,
  reply_to_message_id = msg["message_id"].num.`$`)
""")
                b[j][0][1][1][1][1] = expr
            else:
              if b[j].len > 0:
                preProcess b[j]

        preProcess p.body

        result.add p
        result.add parseStmt("addCommand(\"$1\", cmd_$1)" % name)
      elif $body[i][0].ident == "help":
        result.add parseStmt("addHelp(\"$1\", \"$2\")" % [$body[i][1].ident, body[i][2][0].strVal.replace("\n", "\\n")])
    else:
      discard

macro `@`*(num: int): expr =
  result = parseExpr("args[$1 - 1]" % num.toStrLit.strVal)

template expect*(cond: bool) {.immediate.} =
  if not cond:
    asyncCheck callCommand("help", msg, @[cmd])
    return newFuture[void]()

template expectArgs*(argNum: int) {.immediate.} =
  if args.len < argNum:
    asyncCheck callCommand("help", msg, @[cmd])
    return newFuture[void]()

template checkNull*() {.immediate.} =
  if msg == nil or msg.kind != JObject:
    return newFuture[void]()

template checkText*() {.immediate.} =
  if not msg.hasKey "text":
    return newFuture[void]()

module:
  cmd help:
    expectArgs 1
    var help = "Command " & @1 & " not found."

    if HELPS.hasKey(@1):
      help = HELPS[@1]

    reply help
  cmd cancel:
    cancelReader msg

  help help: "/help [command] - Get help for [command]"
  help cancel: "/cancel - Cancel the ongoing operation"

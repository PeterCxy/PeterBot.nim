import asyncdispatch, json, logging, strutils
import loader, telegram, module

addHandler newConsoleLogger(fmtStr = "$datetime [$levelid] ")

# Parse commandline-like arguments for Telegram commands
# Supported quotes: "'" and '"'
proc parseArgs(str: string): seq[string] =
  result = @[]
  var s = ""
  var inQuotes = false
  var startChar = ' '
  for c in str[1..^1]:
    if not inQuotes and (c == '"' or c == '\''):
      inQuotes = true
      startChar = c
    elif inQuotes and c == startChar:
      inQuotes = false
      startChar = ' '
    elif not inQuotes and c == ' ':
      result.add s
      s = ""
    else:
      s.add c

  if s.len > 0:
    result.add s

proc main() {.async} =
  ME = await(getMe())["username"].str
  info "I am " & ME

  var offset: int64 = 0

  # Main loop
  while true:
    let updates = await getUpdates(offset = $offset, timeout = $600)

    if updates.elems.len == 0:
      continue

    for u in updates.elems:
      offset = u["update_id"].num + 1
      var msg = u["message"]

      if msg == nil:
        continue

      let text = msg["text"].str

      if text.startsWith("/") or text.startsWith("'"):
        # A command starts with "/" or "'"
        var parsed = parseArgs(text)
        var (cmd, args) = (parsed[0], parsed[1..^1])

        if cmd.contains "@":
          # A command that targets a specific bot
          let parts = cmd.split "@"

          if parts[1] != ME:
            break
          else:
            cmd = parts[0]

        # Forward command to the corresponding module
        asyncCheck callCommand(cmd, msg, args)

asyncCheck main()
runForever()

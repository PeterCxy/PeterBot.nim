import json, asyncdispatch, strutils

import telegram
import module as _

proc parseTime(str: string): int =
  result = 0
  var s = ""
  for c in str:
    if c in '0'..'9':
      s &= $c
    elif c == 's':
      result += s.parseInt * 1000
      s = ""
    elif c == 'm':
      result += s.parseInt * 60 * 1000
      s = ""
    elif c == 'h':
      result += s.parseInt * 60 * 60 * 1000
      s = ""

module:
  help hello: "Just say hello."
  cmd hello:
    reply "Hello, @" & msg["from"]["username"].str

  help echo: "/echo arguments... - Echo the arguments"
  cmd echo:
    expect 1
    reply args.join(" ")

  help remind: """
/remind - Reminds you of something after a specific period of time.
This is an interactive command. I'll ask you several questions when you call this command."""
  cmd remind:
    reply "What to remind you of?"
    msg = await readMsg(msg)
    checkNull
    checkText
    var text = msg["text"].str
    reply """Good. But how much time later should I remind you?
Please reply in the following format: AhBmCs (A hours, B minutes and C seconds.)
"""
    msg = await readMsg(msg)
    checkNull
    checkText
    reply "Yes, sir!"
    await sleepAsync parseTime msg["text"].str
    reply "@" & msg["from"]["username"].str & ": " & text

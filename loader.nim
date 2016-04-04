# Config loader
import macros, json, strutils

macro loadConfig(file: string): stmt =
  let conf = slurp(file.strVal)
  var source = ""

  for line in conf.splitLines:
    let l = line.split ":"
    if l.len < 2:
      break
    let key = l[0].strip
    let val = l[1..(l.len - 1)].join(":").strip
    
    if key == "modules":
      # Import modules
      for m in val.split ",":
        source &= "import modules/" & m.strip & "\n"
    else:
      source &= "const cfg_" & key & "* = \"" & val & "\"\n"

  if source.len < 1:
    error "Could not load the config file!"

  return parseStmt source

loadConfig "CONFIG"

# ========================================================================================
#
#                                   Leve Panel
#                                 Argument Parser
#
# ========================================================================================

proc parseArgs() =
  const helpMsg = """
Leve-Panel:
  A lightweight panel for Wayland compositors.
  Copyright (C) 2026 by Mac Taylor

Usage:
  leve-panel [OPTIONS]

Options:
  -h, --help              Show this help message
  -v, --version           Show version number and exit
  -c, --config <file>     Start Leve-Panel using custom config
"""

  var config = ""
  var p = initOptParser()
  p.next()

  case p.kind
  of cmdEnd:
    discard
  of cmdArgument:
    echo "Error: Unknown argument \nUse -h for help \n"
    quit(1)
  of cmdShortOption, cmdLongOption:
    case p.key
    of "c", "config":
      # If value is empty, check the next argument
      if p.val != "":
        config = p.val
      else:
        if paramCount() < 2:
          echo "Error: Missing argument for option '-c'"
          quit(1)
        p.next()
        if p.kind == cmdArgument:
          config = p.key
        else:
          echo "Error: Invalid argument '", p.key, "'"
          quit(1)
    of "h", "help":
      echo helpMsg
      quit(0)
    of "v", "version":
      echo "leve-panel version: ", version
      quit(0)
    else:
      echo "Error: Unknown option '", p.key, "'"
      echo "Use -h for help \n"
      quit(1)

  if config != "":
    if not ('/' in config):
      config = getConfigDir() / config
    if fileExists(config):
      parseConfig(config)
    else:
      echo "Error: Invalid config path"
      quit(1)
  else:
    const defaultConfig: string = staticRead("default.toml")
    config = initFile("default.toml", defaultConfig)
    parseConfig(config)


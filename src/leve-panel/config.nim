# ========================================================================================
#
#                                   Leve Panel
#                                     Config
#
# ========================================================================================

const defaultConfig =
  """
# ========================================================================================
#
#          Leve Panel Default Config
#
# ========================================================================================

# Panel Settings
[Panel]
pos = "bottom"
color = "#070C1E"
size = 46
icon_size = 32
scroll_up = "swaymsg workspace prev"
scroll_down = "swaymsg workspace next"


# Widgets appear left to right
[[Left]]
widget = "menu"
exec = "griddle"
terminal = false

[[Left]]
widget = "favorite"
icon = "folder-blue.png"
exec = "pcmanfm"
terminal = false

[[Left]]
widget = "favorite"
icon = "terminal.png"
exec = "foot"
terminal = false

[[Left]]
widget = "favorite"
icon = "google-chrome.png"
exec = "google-chrome"
terminal = false


# Valid styles for desktop indicator are
# "num", "numbers", and "dots"
[[Center]]
widget = "desktop"
style = "dots"


# Widgets on right side
# are added from right to left
[[Right]]
widget = "power"
exec = "wlogout"
terminal = false

[[Right]]
widget = "clock"
exec = "gsimplecal"
terminal = false

[[Right]]
widget = "volume"
exec = "pavucontrol"
terminal = false
"""

proc getConfigDir(): string =
  # Get XDG_CONFIG_HOME or default "~/.config"
  let dir = getEnv("XDG_CONFIG_HOME", os.getHomeDir() / ".config")
  return dir / "leve-panel"

proc initFile(fileName: string, defaultData: string): string =
  let path = getConfigDir()
  if not fileExists(path / fileName):
    if not dirExists(path):
      createDir(path)
    writeFile(path / fileName, defaultData)

  return path / fileName

proc getIconPath(s: string): string =
  var icon = s

  if not ('/' in icon):
    icon = getConfigDir() / "icons" / icon

  if fileExists(icon):
    return icon
  else:
    echo "Config Error: Invalid icon path"
    return ""

proc getFont(): string =
  var dir = getConfigDir() / "font"
  for kind, path in walkDir(dir):
    if kind == pcFile:
      let (_, _, ext) = splitFile(path)
      if ext == ".ttf":
        return path

  dir = "/usr/share/leve-panel/font"
  for kind, path in walkDir(dir):
    if kind == pcFile:
      let (_, _, ext) = splitFile(path)
      if ext == ".ttf":
        return path

  echo "Warning: Font not found"
  echo "Using fallback..."

  var (output, status) = execCmdEx("""fc-match --format="%{file}" monospace""")
  if status != 0:
    quit("Error: Could not find valid font \n")

  let path = strip(output)

  if fileExists(path):
    echo path
    return path
  else:
    quit("Error: Could not find valid font \n")

var fontPath = getFont()

proc getItems(items: var seq[PanelItem], elements: seq[TomlValueRef]) =
  for elem in elements:
    var item: PanelItem
    if elem.hasKey("widget"):
      try:
        item.widget = parseEnum[WidgetType](elem["widget"].getStr())
      except:
        echo "Config Error: Invalid widget name \"", elem["widget"].getStr(), "\""
        continue
    else: continue

    if item.widget == WidgetType.desktop:
      if elem.hasKey("style"):
        try:
          item.style = parseEnum[Indicator](elem["style"].getStr())
        except:
          echo "Config Error: Invalid desktop style \"", elem["style"].getStr(), "\""
          continue
      else: continue

    if elem.hasKey("icon"):
      item.icon = getIconPath(elem["icon"].getStr())
    if elem.hasKey("exec"):
      item.exec = elem["exec"].getStr()
    if elem.hasKey("terminal"):
      item.terminal = elem["terminal"].getBool()

    items.add(item)

proc parseConfig(configFile: string) =
  echo "\nReading config... \n"

  let config =
    try:
      parseFile(configFile)
    except:
      echo "Error: Failed to parse configuration file"
      return

  # Get Panel Settings
  if config.hasKey("Panel"):
    let panel = config["Panel"]
    if panel.hasKey("pos"):
      try:
        p.pos = parseEnum[PanelPos](panel["pos"].getStr())
      except:
        echo "Config Error: Invalid panel position"
    if panel.hasKey("color"):
      try:
        discard parseHtmlColor(panel["color"].getStr())
        p.color = panel["color"].getStr()
      except:
        echo "Config Error: Invalid background color"
    if panel.hasKey("size"):
      p.size = int32(panel["size"].getFloat())
      if p.size <= 0:
        echo "Config Error: Invalid panel size"
    if panel.hasKey("icon_size"):
      p.iconSize = int32(panel["icon_size"].getFloat())
    # Keep icon size smaller than panel size
    if (p.iconSize <= 0) or (p.iconSize > p.size):
      echo "Config Error: Invalid icon size"
      p.iconSize = p.size
    if panel.hasKey("scroll_up"):
      p.scrollUpCmd = panel["scroll_up"].getStr()
    if panel.hasKey("scroll_down"):
      p.scrollDownCmd = panel["scroll_down"].getStr()

  # Get Panel Items from Elements
  if config.hasKey("Left"):
    let leftElems = config["Left"].getElems()
    leftItems.getItems(leftElems)

  if config.hasKey("Center"):
    let centerElems = config["Center"].getElems()
    centerItems.getItems(centerElems)

  if config.hasKey("Right"):
    let rightElems = config["Right"].getElems()
    rightItems.getItems(rightElems)


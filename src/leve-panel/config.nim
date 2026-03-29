# ========================================================================================
#
#                                   Leve Panel
#                                     Config
#
# ========================================================================================

const defaultConfig =
  """
#          Leve Panel Default Config
#

# Panel Settings
[Panel]
pos = "top"
color = "#070C1E"
size = 46
icon_size = 32
scroll_up = "swaymsg workspace prev"
scroll_down = "swaymsg workspace next"

# Favorite Apps
[[Left]]
widget = "favorite"
icon = "menu.png"
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

# Widgets
[[Right]]
widget = "power"
exec = "power"
terminal = false

[[Right]]
widget = "clock"
exec = "clock"
terminal = false

[[Right]]
widget = "volume"
exec = "volume"
terminal = false
"""

proc getConfigDir(): string =
  let home = getEnv("XDG_CONFIG_HOME")
  if not home.isEmptyOrWhitespace():
    result = home / "leve-panel"
  else:
    result = os.getHomeDir() / ".config" / "leve-panel"

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
    icon = getConfigDir() / "icons" / "favorites" / icon

  if fileExists(icon):
    return icon
  else:
    echo "Error: Invalid icon path \n"
    return ""

proc parseConfig(configFile: string) =
  echo "Reading config..."

  let config =
    try:
      parseFile(configFile)
    except:
      echo "Error: Failed to parse configuration file"
      return

  # Panel
  if config.hasKey("Panel"):
    let panel = config["Panel"]
    if panel.hasKey("pos"):
      p.pos = parseEnum[PanelPos](panel["pos"].getStr())
    if panel.hasKey("color"):
      try:
        discard parseHtmlColor(panel["color"].getStr())
        p.color = panel["color"].getStr()
      except:
        echo "Error: Invalid color in config, using default."
    if panel.hasKey("size"):
      p.size = int32(panel["size"].getInt())
    if panel.hasKey("icon_size"):
      p.iconSize = panel["icon_size"].getInt()
    # Keep icon size smaller than panel size
    if p.iconSize > p.size:
      p.iconSize = p.size
    if panel.hasKey("scroll_up"):
      p.scrollUpCmd = panel["scroll_up"].getStr()
    if panel.hasKey("scroll_down"):
      p.scrollDownCmd = panel["scroll_down"].getStr()

  # Left Side
  let leftElems = config["Left"].getElems()

  for elem in leftElems:
    var item: PanelItem
    if elem.hasKey("widget"):
      item.widget = parseEnum[WidgetType](elem["widget"].getStr())
    if elem.hasKey("icon"):
      item.icon = getIconPath(elem["icon"].getStr())
    if elem.hasKey("exec"):
      item.exec = elem["exec"].getStr()
    if elem.hasKey("terminal"):
      item.terminal = elem["terminal"].getBool()

    leftItems.add(item)

  # Right Side
  let rightElems = config["Right"].getElems()

  for elem in rightElems:
    var item: PanelItem
    if elem.hasKey("widget"):
      item.widget = parseEnum[WidgetType](elem["widget"].getStr())
    if elem.hasKey("icon"):
      item.icon = getIconPath(elem["icon"].getStr())
    if elem.hasKey("exec"):
      item.exec = elem["exec"].getStr()
    if elem.hasKey("terminal"):
      item.terminal = elem["terminal"].getBool()

    rightItems.add(item)

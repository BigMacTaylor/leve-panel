# ========================================================================================
#
#                                   Leve Panel
#                                     Config
#
# ========================================================================================

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

proc getFontPath(): string =
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

var font = try: readFont(getFontPath())
  except: quit("Error: Could not find valid font \n")

proc getItems(p: ptr Panel, key: string): seq[PanelItem] =
  let config =
    try:
      parseFile(p.config)
    except:
      return

  if not config.hasKey(key):
    return

  let elements = config[key].getElems()
  var items: seq[PanelItem]

  for elem in elements:
    var item: PanelItem
    if elem.hasKey("widget"):
      try:
        item.widget = parseEnum[WidgetType](elem["widget"].getStr())
      except:
        continue
    else: continue

    if item.widget == WidgetType.desktop:
      if elem.hasKey("style"):
        try:
          item.style = parseEnum[Indicator](elem["style"].getStr())
        except:
          continue
      else: continue

    if elem.hasKey("icon"):
      item.icon = getIconPath(elem["icon"].getStr())
    if elem.hasKey("exec"):
      item.exec = elem["exec"].getStr()
    if elem.hasKey("terminal"):
      item.terminal = elem["terminal"].getBool()

    items.add(item)

  return items

proc checkElems(elements: seq[TomlValueRef]) =
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

    if panel.hasKey("layer"):
      try:
        p.layer = parseEnum[Layer](panel["layer"].getStr())
      except:
        echo "Config Error: Invalid panel layer"

    if panel.hasKey("pos"):
      try:
        p.pos = parseEnum[PanelPos](panel["pos"].getStr())
      except:
        echo "Config Error: Invalid panel position"

    if panel.hasKey("size"):
      let size = int32(panel["size"].getFloat())
      if size > 0:
        p.size = size
      else:
        echo "Config Error: Invalid panel size"

    if panel.hasKey("margin_top"):
      p.marginTop = int32(panel["margin_top"].getFloat())

    if panel.hasKey("margin_bottom"):
      p.marginBottom = int32(panel["margin_bottom"].getFloat())

    if panel.hasKey("margin_left"):
      p.marginLeft = int32(panel["margin_left"].getFloat())

    if panel.hasKey("margin_right"):
      p.marginRight = int32(panel["margin_right"].getFloat())

    if panel.hasKey("exclusive_zone"):
      p.exclusiveZone = int32(panel["exclusive_zone"].getFloat())
    else:
      case p.pos
      of PanelPos.top:
        p.exclusiveZone = (p.size + p.marginBottom)
      of PanelPos.bottom:
        p.exclusiveZone = (p.size + p.marginTop)
      of PanelPos.left:
        p.exclusiveZone = (p.size + p.marginRight)
      of PanelPos.right:
        p.exclusiveZone = (p.size + p.marginLeft)

    if panel.hasKey("icon_size"):
      p.iconSize = int32(panel["icon_size"].getFloat())

    # Keep icon size smaller than panel size
    if (p.iconSize <= 0) or (p.iconSize > p.size):
      echo "Config Error: Invalid icon size"
      p.iconSize = p.size

    if panel.hasKey("roundness"):
      if int32(panel["roundness"].getFloat()) > 100:
        echo "Config Error: Max roundness = '100'"
        p.radius = 50.0
      else:
        p.radius = int32(panel["roundness"].getFloat()) / 2

    # Keep radius smaller than half of panel size
    if p.radius > (float32(p.size) * 0.5):
      p.radius = float32(p.size) * 0.5

    if panel.hasKey("color"):
      try:
        p.color = parseHtmlColor(panel["color"].getStr())
      except:
        echo "Config Error: Invalid background color"

    if panel.hasKey("scroll_up"):
      p.scrollUpCmd = panel["scroll_up"].getStr()

    if panel.hasKey("scroll_down"):
      p.scrollDownCmd = panel["scroll_down"].getStr()

  # Check Panel Items
  if config.hasKey("Left"):
    let elements = config["Left"].getElems()
    checkElems(elements)

  if config.hasKey("Center"):
    let elements = config["Center"].getElems()
    checkElems(elements)

  if config.hasKey("Right"):
    let elements = config["Right"].getElems()
    checkElems(elements)


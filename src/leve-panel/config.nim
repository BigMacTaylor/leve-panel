# ========================================================================================
#
#                                   Leve Panel
#                                     Config
#
# ========================================================================================

proc parseConfig(configFile: string): seq[Favorite] =
  echo "Reading config..."

  let config =
    try:
      parseFile(configFile)
    except:
      echo "Error: Failed to parse configuration file"
      return

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
      p.icon_size = panel["icon_size"].getInt()
    # Keep icon size smaller than panel size
    if p.icon_size > p.size:
      p.icon_size = p.size

  let apps = config["app"].getElems()

  for app in apps:
    echo app
    var fav: Favorite
    if app.hasKey("name"):
      fav.name = app["name"].getStr()
    if app.hasKey("icon"):
      #fav.icon = getIconPath(app["icon"].getStr())
      fav.icon = app["icon"].getStr()
    if app.hasKey("exec"):
      fav.exec = app["exec"].getStr()
    if app.hasKey("terminal"):
      fav.terminal = app["terminal"].getBool()

    result.add(fav)

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

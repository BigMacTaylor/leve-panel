# ========================================================================================
#
#                                   Leve Panel
#                                  Power Widget
#
# ========================================================================================

proc onPowerBtn(data: pointer) =
  echo "power off menu "
  exec(cast[ptr PanelItem](data))

proc newPowerImg(): Image =
  let iconSize = if p.iconSize > 24:
    p.iconSize - 6
  else:
    p.iconSize
  let padding = (p.size - iconSize) / 2

  var iconPath = getConfigDir() / "icons" / "power.png"
  if not fileExists(iconPath):
    iconPath = "/usr/share/leve-panel/icons/power.png"

  # Create image
  let img = newImage(p.size, p.size)

  # Load Icon
  echo "Load icon: ", iconPath
  let icon =
    try: readImage(iconPath)
    except:
      echo "Error: Icon not found"
      notFoundIcon()

  # Resize Icon
  let sizedIcon = icon.resize(iconSize, iconSize)
  img.draw(sizedIcon, translate(vec2(padding.float32, padding.float32)))

  return img

proc newPowerWidget(i: PanelItem, pos: float32): Widget =
  let startPos: array[2, int] =
    if p.pos == top or p.pos == bottom:
      [int(pos), 0]
    else:
      [0, int(pos)]

  let endPos: array[2, int] =
    if p.pos == top or p.pos == bottom:
      [int(pos) + int(p.size), int(p.size)]
    else:
      [int(p.size), int(pos) + int(p.size)]

  # Create Power Image
  let img = newPowerImg()

  # Create callbacks
  let click: CallBack = (Event.click_l, proc(data: pointer) = onPowerBtn(addr i))
  let callBacks: seq[CallBack] = @[click]

  # Create widget
  var widget: Widget = Widget(widgetType: power, startPos: startPos, endPos: endPos, img: img, callBacks: callBacks)

  return widget


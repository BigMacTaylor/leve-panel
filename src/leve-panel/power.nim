# ========================================================================================
#
#                                   Leve Panel
#                                  Power widget
#
# ========================================================================================

proc onPowerBtn(data: pointer) =
  echo "power off menu "
  exec(cast[ptr PanelItem](data))

proc newPowerIcon(): Image =
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

proc newPowerWidget(i: PanelItem, startPos: array[2, int], endPos: array[2, int]): Widget =
  # Create icon
  let icon = newPowerIcon()

  # Create callbacks
  let click: CallBack = (Event.click_l, proc(data: pointer) = onPowerBtn(addr i))
  let callBacks: seq[CallBack] = @[click]

  # Create widget
  var widget: Widget = Widget(startPos: startPos, endPos: endPos, img: icon, callBacks: callBacks)

  return widget


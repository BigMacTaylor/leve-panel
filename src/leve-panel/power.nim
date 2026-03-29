# ========================================================================================
#
#                                   Leve Panel
#                                  Power widget
#
# ========================================================================================


const powerCmd = "power off"



proc onPowerBtn(data: pointer) =
  echo "on click ", powerCmd
  #echo cast[ptr Favorite](fav).name
  #exec(cast[ptr Favorite](fav))
  #echo new.name

proc newPowerIcon(): Image =
  let iconSize = if p.iconSize > 24:
    p.iconSize - 6
  else:
    p.iconSize
  let padding = (p.size - iconSize) / 2
  let iconPath = getConfigDir() / "icons" / "favorites"
  let iconName = "power.png"

  # Create image
  let img = newImage(p.size, p.size)

  # Load Icon
  echo iconPath / iconName
  let icon = readImage(iconPath / iconName)

  # Resize Icon
  let sizedIcon = icon.resize(iconSize, iconSize)
  img.draw(sizedIcon, translate(vec2(padding.float32, padding.float32)))

  return img




proc newPowerWidget(startPos: array[2, int], endPos: array[2, int]): Widget =
  # Create icon
  let icon = newPowerIcon()

  # Create callbacks
  let click: CallBack = ("click_l", onPowerBtn)
  let callBacks: seq[CallBack] = @[click]

  # Create widget
  var widget: Widget = Widget(startPos: startPos, endPos: endPos, img: icon, callBacks: callBacks)

  return widget
























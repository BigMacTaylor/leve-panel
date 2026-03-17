# ========================================================================================
#
#                                   Leve Panel
#                                 Volume widget
#
# ========================================================================================

var vol_image: Image
var cur_vol = 100

proc getVolume(): int =
  let cmd = "wpctl get-volume @DEFAULT_AUDIO_SINK@"
  let (output, status) = execCmdEx(cmd, options={})

  if status != 0:
    echo "Error getting volume level"
    return

  # Clean output string
  let s = output.splitWhitespace()[1] # Get "1.0"
  let f = parseFloat(s)

  #return toInt(f * 100)
  return cur_vol
#[
proc setVolume(volume: int) =
  let cmd = "wpctl set-volume @DEFAULT_AUDIO_SINK@ " & $volume & "%"
  #discard execProcess(cmd & $volume & "%")
  let (output, status) = execCmdEx(cmd, options={})

  if status != 0:
    echo "Error setting volume level"
    return

proc volumeChanged(scale: Range) =
  let volume = int(scale.getValue())
  setVolume(volume)
]#
proc updateIcon(w: Image) =
  let iconSize = if p.iconSize > 24:
    p.iconSize - 10
  else:
    p.iconSize
  let padding = (p.size - iconSize) / 2
  let iconPath = getConfigDir() / "icons" / "volume"
  var iconName: string
  let vol = getVolume()
  echo vol

  if vol <= 0:
    iconName = "audio-volume-muted-symbolic.png"
  elif vol > 0 and vol <= 50:
    iconName = "audio-volume-low-symbolic.png"
  elif vol > 50 and vol <= 75:
    iconName = "audio-volume-medium-symbolic.png"
  else: # vol > 75
    iconName = "audio-volume-high-symbolic.png"

  # Load Icon
  echo iconPath / iconName
  let icon = readImage(iconPath / iconName)

  # Resize Icon
  let sizedIcon = icon.resize(iconSize, iconSize)
  w.draw(sizedIcon, translate(vec2(padding.float32, padding.float32)))

  return
#[
proc onScroll(w: EventBox, e: EventScroll): bool =
  echo "scroll"
  let vol = getVolume()
  w.updateIcon()

proc muteVolume(w: EventBox, event: EventButton): bool =
  if cur_vol == 100:
    cur_vol = 0
  else:
    cur_vol = 100
  echo "mute"
  setVolume(0)
  w.updateIcon()
]#
proc newVolWidget(): Image =
  let padding = (p.size - p.iconSize) / 2

  # Create widget
  let w = newImage(p.size, p.size)

  w.updateIcon()




  #w.connect("scroll-event", onScroll)
  #w.connect("button-press-event", muteVolume)

  #w = w.updateIcon(vol)
  return w



























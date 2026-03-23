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
proc updateIcon(img: Image) =
  let iconSize = if p.iconSize > 24:
    p.iconSize - 4
  else:
    p.iconSize
  let padding = (p.size - iconSize) / 2
  let iconPath = getConfigDir() / "icons" / "volume"
  var iconName: string
  let vol = getVolume()
  echo "volume ", vol

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
  img.draw(sizedIcon, translate(vec2(padding.float32, padding.float32)))

  return

proc onMute(w: pointer) =
  echo "mute"
  if cur_vol == 100:
    cur_vol = 0
  else:
    cur_vol = 100
  echo "mute"
  #setVolume(0)
  echo "volume ", getVolume()
  #cast[Image](w).updateIcon()


  let buffer = drawFrame(addr p)

  # Attach and Commit
  p.surface.damage(0, 0, high(int32), high(int32))
  p.surface.attach(buffer, 0, 0)
  p.surface.commit()



proc onVolClick(icon: pointer) =
  echo "open volume"
  #cast[Image](icon).updateIcon()

proc volUp(icon: pointer) =
  echo "vol up"
  #cast[Image](icon).updateIcon()

proc volDown(icon: pointer) =
  echo "vol down"
  #cast[Image](icon).updateIcon()

proc newVolWidget(startPos: array[2, int], endPos: array[2, int]): Widget =
  let padding = (p.size - p.iconSize) / 2

  # Create widget
  let icon = newImage(p.size, p.size)

  icon.updateIcon()

  # Create callbacks
  var callBacks: seq[CallBack] = @[]
  let click: CallBack = ("click_l", onVolClick)
  callBacks.add(click)
  let mute: CallBack = ("click_m", onMute)
  callBacks.add(mute)
  let scrollUp: CallBack = ("scroll_up", volUp)
  callBacks.add(scrollUp)
  let scrollDown: CallBack = ("scroll_down", volDown)
  callBacks.add(scrollDown)

  # Create widget
  var widget: Widget = Widget(startPos: startPos, endPos: endPos, img: icon, callBacks: callBacks)
  widget.data = addr widget

  return widget

























# ========================================================================================
#
#                                   Leve Panel
#                                 Volume widget
#
# ========================================================================================

var vol_image: Image
var cur_vol = 100
var volMute = false

type VolState = enum
  mute
  low
  med
  high

var volState = VolState.high


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

proc getVolState(): VolState =
  if cur_vol <= 0 or volMute:
    return VolState.mute
  elif cur_vol > 0 and cur_vol <= 50:
    return VolState.low
  elif cur_vol > 50 and cur_vol <= 75:
    return VolState.med
  else: # cur_vol > 75
    return VolState.high

volState = getVolState()

proc newVolImg(): Image =
  let iconSize = if p.iconSize > 24:
    p.iconSize - 4
  else:
    p.iconSize
  let padding = (p.size - iconSize) / 2
  let iconPath = getConfigDir() / "icons" / "volume"
  var iconName: string

  echo "volume ", cur_vol
  echo "volState = ", volState

  case volState
  of VolState.mute:
    iconName = "audio-volume-muted-symbolic.png"
  of VolState.low:
    iconName = "audio-volume-low-symbolic.png"
  of VolState.med:
    iconName = "audio-volume-medium-symbolic.png"
  else: # High
    iconName = "audio-volume-high-symbolic.png"

  # Create image
  let img = newImage(p.size, p.size)

  # Load Icon
  echo iconPath / iconName
  let icon = readImage(iconPath / iconName)

  # Resize Icon
  let sizedIcon = icon.resize(iconSize, iconSize)
  img.draw(sizedIcon, translate(vec2(padding.float32, padding.float32)))

  return img

proc onVolClick(data: pointer) =
  echo "open volume"
  echo "volume ", getVolume()

proc onMute(data: pointer) =
  echo "on mute"
  echo "volume ", getVolume()

  if volMute:
    volMute = false
  else:
    volMute = true
    #volState = VolState.mute

  # Update state and Image
  volState = getVolState()

  cast[ptr Widget](data).img = newVolImg()
  updateWidget(cast[ptr Widget](data))
  p.surface.wl_surface_commit()

proc volUp(data: pointer) =
  echo "vol up"
  echo "volume ", getVolume()
  let curVolState = volState

  # Check bounds
  if cur_vol>= 100 and not volMute:
    return

  # Change current volume level
  if cur_vol < 95:
    cur_vol = cur_vol + 5
  else:
    cur_vol = 100

  # Unmute on scroll up
  if cur_vol <= 0 or volMute:
    volMute = false

  # Update state and Image
  volState = getVolState()
  if curVolState == volState:
    return

  cast[ptr Widget](data).img = newVolImg()
  updateWidget(cast[ptr Widget](data))
  p.surface.wl_surface_commit()

proc volDown(data: pointer) =
  echo "vol down"
  echo "volume ", getVolume()
  let curVolState = volState

  if cur_vol <= 0:
    return

  if cur_vol > 5:
    cur_vol = cur_vol - 5
  else:
    cur_vol = 0

  volState = getVolState()
  if curVolState == volState:
    return

  cast[ptr Widget](data).img = newVolImg()
  updateWidget(cast[ptr Widget](data))
  p.surface.wl_surface_commit()

proc newVolWidget(startPos: array[2, int], endPos: array[2, int]): Widget =
  # Create volume Image
  let icon = newVolImg()

  # Create callbacks
  var callBacks: seq[CallBack] = @[]
  let click: CallBack = ("click_m", onVolClick)
  callBacks.add(click)
  let mute: CallBack = ("click_l", onMute)
  callBacks.add(mute)
  let scrollUp: CallBack = ("scroll_up", volUp)
  callBacks.add(scrollUp)
  let scrollDown: CallBack = ("scroll_down", volDown)
  callBacks.add(scrollDown)

  # Create widget
  var widget: Widget = Widget(widgetType: WidgetType.volume, startPos: startPos, endPos: endPos, img: icon, callBacks: callBacks)

  return widget











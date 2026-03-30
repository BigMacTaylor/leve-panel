# ========================================================================================
#
#                                   Leve Panel
#                                 Volume widget
#
# ========================================================================================

type VolState = enum
  mute
  low
  med
  high

var volMute = false
var cur_vol = 100
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

proc getMute(): bool =
  let cmd = "wpctl get-volume @DEFAULT_AUDIO_SINK@"
  var (output, status) = execCmdEx(cmd, options={})

  if status != 0:
    echo "Error getting volume level"
    return

  # Clean output string
  var s = output.strip()
  let isMuted = s.endsWith("[MUTED]")
  echo output
  echo isMuted
  return isMuted

proc getVolume(): int =
  let cmd = "wpctl get-volume @DEFAULT_AUDIO_SINK@"
  let (output, status) = execCmdEx(cmd, options={})

  if status != 0:
    echo "Error getting volume level"
    return

  # Clean output string
  let s = output.splitWhitespace()[1] # Get "1.0"
  let f = parseFloat(s)

  return toInt(f * 100)

proc getVolState(): VolState =
  if cur_vol <= 0 or volMute:
    return VolState.mute
  elif cur_vol > 0 and cur_vol <= 50:
    return VolState.low
  elif cur_vol > 50 and cur_vol <= 75:
    return VolState.med
  else: # cur_vol > 75
    return VolState.high

volMute = getMute()
cur_vol = getVolume()
volState = getVolState()

proc newVolImg(): Image =
  let iconSize = if p.iconSize > 24:
    p.iconSize - 4
  else:
    p.iconSize
  let padding = (p.size - iconSize) / 2
  let iconPath = getConfigDir() / "icons" / "volume"
  var iconName: string

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
  let icon = try:
    readImage(iconPath / iconName)
  except:
    echo "Error: Icon not found"
    notFoundIcon()

  # Resize Icon
  let sizedIcon = icon.resize(iconSize, iconSize)
  img.draw(sizedIcon, translate(vec2(padding.float32, padding.float32)))

  return img

proc onVolClick(data: pointer) =
  echo "open volume control"
  echo "volume ", getVolume()

  let cmd = cast[ptr PanelItem](data).exec
  discard execShellCmd(cmd & " &")

proc onMute(data: pointer) =
  echo "on mute"
  echo "volume ", getVolume()
  let cmd = "wpctl set-mute @DEFAULT_AUDIO_SINK@ "

  if volMute:
    volMute = false
    discard execShellCmd(cmd & "0")
  else:
    volMute = true
    discard execShellCmd(cmd & "1")

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
  if cur_vol >= 100 and not volMute:
    return

  let cmd = "wpctl set-volume @DEFAULT_AUDIO_SINK@ "

  # Change current volume level
  if cur_vol < 95:
    cur_vol = cur_vol + 5
    discard execShellCmd(cmd & $cur_vol & "%")
  else:
    cur_vol = 100
    discard execShellCmd(cmd & "100%")

  # Unmute on scroll up
  #if cur_vol <= 0 or volMute:
  if volMute:
    volMute = false
    let muteCmd = "wpctl set-mute @DEFAULT_AUDIO_SINK@ "
    discard execShellCmd(muteCmd & "0")
  echo "mute state ", volMute

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

  # Check bounds
  if cur_vol <= 0:
    return

  let cmd = "wpctl set-volume @DEFAULT_AUDIO_SINK@ "

  # Change current volume level
  if cur_vol > 5:
    cur_vol = cur_vol - 5
    discard execShellCmd(cmd & $cur_vol & "%")
  else:
    cur_vol = 0
    discard execShellCmd(cmd & "0%")

  # Update state and Image
  volState = getVolState()
  if curVolState == volState:
    return

  cast[ptr Widget](data).img = newVolImg()
  updateWidget(cast[ptr Widget](data))
  p.surface.wl_surface_commit()

proc newVolWidget(i: PanelItem, startPos: array[2, int], endPos: array[2, int]): Widget =
  # Create volume Image
  let icon = newVolImg()

  # Create callbacks
  var callBacks: seq[CallBack] = @[]
  let click: CallBack = ("click_m", proc(data: pointer) = onVolClick(addr i))
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











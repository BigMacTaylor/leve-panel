# ========================================================================================
#
#                                   Leve Panel
#                                 Volume widget
#
# ========================================================================================

var volMute = false
var cur_vol = 100
var volState = VolState.mute

let opts = SubprocessOptions(useStdout: true)
let volProcess = startSubprocess("pactl", ["subscribe"], opts)

proc getSinkStatus(): bool =
  let cmd = "pactl get-sink-volume @DEFAULT_SINK@ > /dev/null"
  var p = startProcess(cmd, options = {poEvalCommand, poParentStreams})

  # return exit code, or -1 if timeout is reached
  let status = p.waitForExit(1000)

  if p.running():
    p.terminate() # p.kill()

  p.close()

  if status == 0:
    return true
  else:
    return false

proc getMute(): bool =
  #let cmd = """amixer get Master | grep -q "\[off\]" && echo "Muted" || echo "Unmuted" """
  let cmd = """pactl get-sink-mute @DEFAULT_SINK@ | grep -oP 'Mute: \K.*' """
  let (output, status) = execCmdEx(cmd)

  if status != 0:
    echo "Error: Could not get mute status"
    return false

  if output.strip() == "yes": # "Muted"
    return true
  elif output.strip() == "no": # "Unmuted"
    return false
  else:
    echo "Error: Could not get mute status"
    return false

proc getVolume(): int =
  #let cmd = "amixer get Master | awk -F'[][]' '/Left:/ { print $2 }' | tr -d '%'"
  let cmd = """pactl get-sink-volume @DEFAULT_SINK@ | grep -Po '\d+(?=%)' | head -n 1 """
  let (output, status) = execCmdEx(cmd)

  if status != 0:
    echo "Error: Could not get volume level"
    return 100

  return
    try: 
      parseInt(output.strip)
    except:
      echo "Error: Could not get volume level"
      100

proc getVolState(): VolState =
  if cur_vol <= 0 or volMute:
    return VolState.mute
  elif cur_vol > 0 and cur_vol <= 50:
    return VolState.low
  elif cur_vol > 50 and cur_vol <= 75:
    return VolState.med
  else: # cur_vol > 75
    return VolState.high

echo "\nGetting volume status... \n"
if getSinkStatus():
  volMute = getMute()
  cur_vol = getVolume()
  volState = getVolState()
else:
  volProcess.close()
  echo "\nError: Could not get sink status."
  echo "Is pulse-audio running?"

# ----------------------------------------------------------------------------------------
#                                    Create Image
# ----------------------------------------------------------------------------------------

proc newVolImg(): Image =
  let iconSize =
    if p.iconSize > 24:
      p.iconSize - 4
    else:
      p.iconSize

  let padding = (p.size - iconSize) / 2
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

  var iconPath = getConfigDir() / "icons" / iconName
  if not fileExists(iconPath):
    iconPath = "/usr/share/leve-panel/icons" / iconName

  # Create image
  let img = newImage(p.size, p.size)

  # Load Icon
  echo "Load icon: ", iconPath
  let icon = try:
    readImage(iconPath)
  except:
    echo "Error: Icon not found"
    notFoundIcon()

  # Resize Icon
  let sizedIcon = icon.resize(iconSize, iconSize)
  img.draw(sizedIcon, translate(vec2(padding.float32, padding.float32)))

  return img

# ----------------------------------------------------------------------------------------
#                                    Callbacks
# ----------------------------------------------------------------------------------------

proc onVolClick(data: pointer) =
  echo "open volume control"
  exec(cast[ptr PanelItem](data))

proc onMute(data: pointer) =
  echo "on mute"
  let cmd = "pactl set-sink-mute @DEFAULT_SINK@ "

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
  echo "volume up"
  let curVolState = volState

  # Check bounds
  if cur_vol >= 100 and not volMute:
    return

  let cmd = "pactl set-sink-volume @DEFAULT_SINK@ "

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
    let muteCmd = "pactl set-sink-mute @DEFAULT_SINK@ "
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
  echo "volume down"
  let curVolState = volState

  # Check bounds
  if cur_vol <= 0:
    return

  let cmd = "pactl set-sink-volume @DEFAULT_SINK@ "

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

# ----------------------------------------------------------------------------------------
#                                    Create Widget
# ----------------------------------------------------------------------------------------

proc newVolWidget(i: PanelItem, pos: float32): Widget =
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

  # Create volume Image
  let icon = newVolImg()

  # Create callbacks
  var callBacks: seq[CallBack] = @[]
  if getSinkStatus():
    let click: CallBack = (Event.click_m, proc(data: pointer) = onVolClick(addr i))
    callBacks.add(click)
    let mute: CallBack = (Event.click_l, onMute)
    callBacks.add(mute)
    let scrollUp: CallBack = (Event.scroll_up, volUp)
    callBacks.add(scrollUp)
    let scrollDown: CallBack = (Event.scroll_down, volDown)
    callBacks.add(scrollDown)

  # Create widget
  var widget: Widget = Widget(widgetType: volume, startPos: startPos, endPos: endPos, img: icon, callBacks: callBacks)

  return widget

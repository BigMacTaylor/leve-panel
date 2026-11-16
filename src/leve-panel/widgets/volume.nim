# ========================================================================================
#
#                                   Leve Panel
#                                 Volume Widget
#
# ========================================================================================

var volMute = false
var curVol = 100
var volState = WidgetState.off
var volProcess: Subprocess

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

proc getVolState(): WidgetState =
  if volMute or curVol <= 0: return WidgetState.off
  elif curVol <= 50: return WidgetState.low
  elif curVol <= 75: return WidgetState.med
  else: # curVol > 75
    return WidgetState.high

proc checkVolStatus() =
  echo "\nChecking volume status... \n"
  if getSinkStatus():
    volMute = getMute()
    curVol = getVolume()
    volState = getVolState()
  else:
    volProcess.close()
    echo "\nError: Could not get sink status."
    echo "Is pulse-audio running?"

# ----------------------------------------------------------------------------------------
#                                    Draw Image
# ----------------------------------------------------------------------------------------

proc drawVolImg(w: ptr Widget) =
  let iconSize =
    if p.iconSize > 24:
      p.iconSize - 4
    else:
      p.iconSize

  let padding = (p.size - iconSize) / 2

  let iconPath = getStateIconPath("volume", volState)

  # Load Icon
  echo "Load icon: ", iconPath
  let icon = try:
    readImage(iconPath)
  except:
    echo "Error: Icon not found"
    notFoundIcon()

  # Resize Icon
  let sizedIcon = icon.resize(iconSize, iconSize)
  w.img.draw(sizedIcon, translate(vec2(padding.float32, padding.float32)))

# ----------------------------------------------------------------------------------------
#                                    Callbacks
# ----------------------------------------------------------------------------------------

proc onVolClick(data: pointer, item: PanelItem) =
  debug "open volume control"
  exec(item)

proc onMute(data: pointer) =
  debug "on mute"
  let cmd = "pactl set-sink-mute @DEFAULT_SINK@ "

  if volMute:
    volMute = false
    discard execShellCmd(cmd & "0")
    tt.text = "Volume: " & $curVol & "%"
  else:
    volMute = true
    discard execShellCmd(cmd & "1")
    tt.text = "Volume: Muted"

  # Update tooltip
  updateTooltip(addr tt)
  tt.surface.wl_surface_commit()

  # Update state and Image
  volState = getVolState()

  p.surface.wl_surface_attach(p.buffer, 0, 0)
  clearBgImg(cast[ptr Widget](data))
  drawVolImg(cast[ptr Widget](data))
  updateWidget(cast[ptr Widget](data))
  p.surface.wl_surface_commit()

proc volUp(data: pointer) =
  debug "volume up"
  let curVolState = volState

  # Check bounds
  if curVol >= 100 and not volMute:
    return

  let cmd = "pactl set-sink-volume @DEFAULT_SINK@ "

  # Change current volume level
  if curVol < 95:
    curVol = curVol + 5
    discard execShellCmd(cmd & $curVol & "%")
  else:
    curVol = 100
    discard execShellCmd(cmd & "100%")

  # Unmute on scroll up
  #if curVol <= 0 or volMute:
  if volMute:
    volMute = false
    let muteCmd = "pactl set-sink-mute @DEFAULT_SINK@ "
    discard execShellCmd(muteCmd & "0")
  debug "mute state ", volMute

  # Update tooltip
  tt.text = "Volume: " & $curVol & "%"
  updateTooltip(addr tt)
  tt.surface.wl_surface_commit()

  # Update state and Image
  volState = getVolState()
  if curVolState == volState:
    return

  p.surface.wl_surface_attach(p.buffer, 0, 0)
  clearBgImg(cast[ptr Widget](data))
  drawVolImg(cast[ptr Widget](data))
  updateWidget(cast[ptr Widget](data))
  p.surface.wl_surface_commit()

proc volDown(data: pointer) =
  debug "volume down"
  let curVolState = volState

  # Check bounds
  if curVol <= 0:
    return

  let cmd = "pactl set-sink-volume @DEFAULT_SINK@ "

  # Change current volume level
  if curVol > 5:
    curVol = curVol - 5
    discard execShellCmd(cmd & $curVol & "%")
  else:
    curVol = 0
    discard execShellCmd(cmd & "0%")

  # Update tooltip
  tt.text = "Volume: " & $curVol & "%"
  updateTooltip(addr tt)
  tt.surface.wl_surface_commit()

  # Update state and Image
  volState = getVolState()
  if curVolState == volState:
    return

  p.surface.wl_surface_attach(p.buffer, 0, 0)
  clearBgImg(cast[ptr Widget](data))
  drawVolImg(cast[ptr Widget](data))
  updateWidget(cast[ptr Widget](data))
  p.surface.wl_surface_commit()

# ----------------------------------------------------------------------------------------
#                                    Create Widget
# ----------------------------------------------------------------------------------------

proc newVolWidget(item: PanelItem, pos: float32): Widget =
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

  # Create Image
  let img = newImage(p.size, p.size)

  # Create callbacks
  var callBacks: seq[CallBack] = @[]
  if getSinkStatus():
    let click: CallBack = (Event.click_m, proc(data: pointer) = onVolClick(data, item))
    callBacks.add(click)
    let mute: CallBack = (Event.click_l, onMute)
    callBacks.add(mute)
    let scrollUp: CallBack = (Event.scroll_up, volUp)
    callBacks.add(scrollUp)
    let scrollDown: CallBack = (Event.scroll_down, volDown)
    callBacks.add(scrollDown)

  # Create widget
  var widget: Widget = Widget(
    widgetType: volume,
    startPos: startPos,
    endPos: endPos,
    img: img,
    callBacks: callBacks,
  )

  drawVolImg(addr widget)

  return widget

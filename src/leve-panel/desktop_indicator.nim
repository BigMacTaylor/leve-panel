import json

## Helper to construct a raw Sway IPC message packet
proc createIpcPacket(msgType: uint32, payload: string): string =
# Package an IPC command with headers: Magic string, length, and type
  let len = payload.len.int32
  result = IPC_MAGIC & "\0\0\0\0" & "\x02\0\0\0" # 2 for subscribe
  # Replace \0\0\0\0 with our actual len (in little endian)
  result[6] = char(len and 0xFF)
  result[7] = char((len shr 8) and 0xFF)
  result[8] = char((len shr 16) and 0xFF)
  result[9] = char((len shr 24) and 0xFF)
  result.add(payload)



proc getCurrentSwayWorkspace(): string =
  let (output, exitCode) = execCmdEx("swaymsg -t get_workspaces")
  
  if exitCode != 0:
    return "Error: Could not connect to sway"

  let workspaces = parseJson(output)
  
  # Find focused workspace
  for workspace in workspaces:
    if workspace["focused"].getBool():
      return workspace["name"].getStr()

  return "None"

proc getNumSwayWorkspaces(): string =
  let (output, exitCode) = execCmdEx("swaymsg -t get_workspaces")
  
  if exitCode != 0:
    return "Error: Could not connect to sway"

  let json = parseJson(output)
  var workspaces = 0

  for workspace in json:
    workspaces = workspaces + 1

  return $workspaces

proc desktopDotsImg(): Image =
  let img = newImage(p.size * 2, p.size)
  let curWS = getCurrentSwayWorkspace()
  let numWS = getNumSwayWorkspaces()

  let text = curWS & " - " & numWS

  # Draw Text
  let font = try:
    readFont(fontPath)
  except:
    fontPath = getFont()
    readFont(fontPath)
  font.size = 15
  font.paint.color = color(1, 1, 1) # White

  # Center text both horizontally and vertically
  let layout = font.typeset(
    text,
    bounds = vec2(img.width.float, img.height.float),
    hAlign = CenterAlign,  # Horizontal: Left, Center, Right
    vAlign = MiddleAlign   # Vertical: Top, Middle, Bottom
  )

  # Draw the text within the specified bounds, centered
  img.fillText(layout, translate(vec2(0, 0)))
  #clock.fillText(font.typeset(text, vec2(180, 180)), translate(vec2(0, 0)))

  return img

proc desktopNumImg(): Image =
  let img = newImage(p.size * 2, p.size)
  let text = getCurrentSwayWorkspace()

  # Draw Text
  let font = try:
    readFont(fontPath)
  except:
    fontPath = getFont()
    readFont(fontPath)
  font.size = 15
  font.paint.color = color(1, 1, 1) # White

  # Center text both horizontally and vertically
  let layout = font.typeset(
    text,
    bounds = vec2(img.width.float, img.height.float),
    hAlign = CenterAlign,  # Horizontal: Left, Center, Right
    vAlign = MiddleAlign   # Vertical: Top, Middle, Bottom
  )

  # Draw the text within the specified bounds, centered
  img.fillText(layout, translate(vec2(0, 0)))
  #clock.fillText(font.typeset(text, vec2(180, 180)), translate(vec2(0, 0)))

  return img

proc newDesktopWidget(startPos: array[2, int], endPos: array[2, int]): Widget =
  # Create volume Image
  #if p.desktop_indicator == Indicator.dots:
  if false:
    newDesktopImg = desktopDotsImg
  else:
    newDesktopImg = desktopNumImg
  let icon = newDesktopImg()

  # Create callbacks

  # Create widget
  var widget: Widget = Widget(widgetType: WidgetType.desktop, startPos: startPos, endPos: endPos, img: icon)

  return widget

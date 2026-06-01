# ========================================================================================
#
#                                   Leve Panel
#                                 Desktop Widget
#
# ========================================================================================

import json
import std/algorithm


# Helper to construct a raw Sway IPC message packet
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

# Helper to read an exact amount of bytes from the socket
proc readExact(fd: cint, bytesToRead: int): string =
  result = newString(bytesToRead)
  var totalRead = 0
  while totalRead < bytesToRead:
    let chunk = read(fd, result[totalRead].addr, bytesToRead - totalRead)
    if chunk <= 0:
      echo("Error: Sway connection closed or failed while reading.")
      break
    totalRead += chunk

proc getCurrentWS(): string =
  let (output, exitCode) = execCmdEx("swaymsg -t get_workspaces")
  
  if exitCode != 0:
    return "Error: Could not connect to sway"

  let workspaces = parseJson(output)
  
  # Find focused workspace
  for workspace in workspaces:
    if workspace["focused"].getBool():
      return workspace["name"].getStr()

proc getWsFromJson(json: string): string =
  # Parse the string into a JSON node
  let eventNode = try:
    parseJson(json)
  except:
    return getCurrentWS()

  if not eventNode.hasKey("change"):
    return getCurrentWS()

  # Parse the "change" event
  let eventType = eventNode["change"].getStr()

  if eventType == "focus":
    echo "focus"
    let oldWS = eventNode["old"]["name"].getStr()
    echo "old ws ", oldWS
    let curWS = eventNode["current"]["name"].getStr()
    echo "new ws ", curWS
    return curWS

    #let containerName = eventNode["container"]["name"].getStr()
    #let containerId = eventNode["container"]["id"].getInt()
  
    #echo "Focused window: ", containerName, " (ID: ", containerId, ")"

  elif eventType == "init":
    let curWS = parseInt(eventNode["current"]["name"].getStr())
    echo "init ws ", curWS
    workspaces.insert(curWS, workspaces.lowerBound(curWS))

    let focus = eventNode["current"]["focused"].getbool()
    echo "init ws focus ", focus
    echo workspaces
    if focus:
      return $curWS
    else:
      return getCurrentWS()

  elif eventType == "empty":
    let curWS = parseInt(eventNode["current"]["name"].getStr())
    echo "remove ws: ", curWS
    let idx = workspaces.find(curWS)
    if idx != -1:
      workspaces.delete(idx)
    echo workspaces
    return getCurrentWS()

proc initWorkspaces() =
  let (output, exitCode) = execCmdEx("swaymsg -t get_workspaces")
  
  if exitCode != 0:
    echo "Error: Could not connect to sway"

  let json = parseJson(output)

  for workspace in json:
    workspaces.add(parseInt(workspace["name"].getStr()))

proc getNumWorkspaces(): int =
  var n = 0
  for workspace in workspaces:
    n = n + 1

  return n

proc desktopDotsImg(curWS: string): Image =
  let img = newImage(p.size * 4, p.size)
  let centerX: float32 = float32(p.size * 2)
  let numCircles: int = getNumWorkspaces()
  #let radius: int = 4
  let radius: int = p.size div 10
  let color = rgba(255, 255, 255, 255)
  #let colorDim = rgba(180, 180, 180, 255)
  let ctx = img.newContext()
  ctx.fillStyle = color

  # Row configuration
  let gap: int = 10 # Gap between circles
  let rowWidth: int = (numCircles * radius * 2) + (gap * (numCircles - 1))
  let startX: float32 = centerX - (rowWidth / 2) + float32(radius)

  var i = 0

  for workspace in workspaces:
    let posX = startX + float32(i * (radius * 2 + gap))
    let posY = p.size / 2

    if $workspace == curWS:
      ctx.fillCircle(circle(vec2(posX, posY), float32(radius + 2)))
    else:
      ctx.fillCircle(circle(vec2(posX, posY), float32(radius)))

    i = i + 1

  return img

proc desktopNumbersImg(curWS: string): Image =
  let img = newImage(p.size * 4, p.size)
  var text = ""

  for workspace in workspaces:
    if $workspace == curWS:
      text = text & "[" & $workspace & "]"
    else:
      text = text & "\xA0" & $workspace & "\xA0"

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

proc desktopNumImg(curWS: string): Image =
  let img = newImage(p.size * 4, p.size)
  let text = curWS

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
  # Get initial desktops
  initWorkspaces()

  # Create volume Image
  if p.desktop_indicator == Indicator.dots:
    newDesktopImg = desktopDotsImg
  elif p.desktop_indicator == Indicator.numbers:
    newDesktopImg = desktopNumbersImg
  else:
    newDesktopImg = desktopNumImg

  let icon = newDesktopImg(getCurrentWS())

  # Create callbacks

  # Create widget
  var widget: Widget = Widget(widgetType: WidgetType.desktop, startPos: startPos, endPos: endPos, img: icon)

  return widget

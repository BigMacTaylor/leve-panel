# ========================================================================================
#
#                                   Leve Panel
#                                 Desktop Widget
#
# ========================================================================================

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

proc getNumWorkspaces(): int =
  var n = 0
  for workspace in workspaces:
    n = n + 1

  return n

proc hDesktopDotsImg(curWS: string): Image =
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

proc vDesktopDotsImg(curWS: string): Image =
  let img = newImage(p.size, p.size * 4)
  let centerX: float32 = float32(p.size * 2)
  let numCircles: int = getNumWorkspaces()
  let radius: int = p.size div 10
  let color = rgba(255, 255, 255, 255)
  let ctx = img.newContext()
  ctx.fillStyle = color

  # Row configuration
  let gap: int = 10 # Gap between circles
  let rowHeight: int = (numCircles * radius * 2) + (gap * (numCircles - 1))
  let startX: float32 = centerX - (rowHeight / 2) + float32(radius)

  var i = 0

  for workspace in workspaces:
    let posX = p.size / 2
    let posY = startX + float32(i * (radius * 2 + gap))

    if $workspace == curWS:
      ctx.fillCircle(circle(vec2(posX, posY), float32(radius + 2)))
    else:
      ctx.fillCircle(circle(vec2(posX, posY), float32(radius)))

    i = i + 1

  return img

proc hDesktopNumbersImg(curWS: string): Image =
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

  return img

proc vDesktopNumbersImg(curWS: string): Image =
  let img = newImage(p.size, p.size * 4)
  var text = ""

  for workspace in workspaces:
    if $workspace == curWS:
      text = text & "[" & $workspace & "]" & "\n"
    else:
      text = text & "\xA0" & $workspace & "\xA0" & "\n"

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

  return img

proc desktopNumImg(curWS: string): Image =
  let img = newImage(p.size, p.size)
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

proc newDesktopWidget(i: PanelItem, pos: float32): Widget =
  let startPos: array[2, int] =
    if p.pos == top or p.pos == bottom:
      [int(pos), 0]
    else:
      [0, int(pos)]

  let endPos: array[2, int] =
    if p.pos == top or p.pos == bottom:
      if i.style == num:
        [int(pos) + int(p.size), int(p.size)]
      else:
        [int(pos) + (4 * p.size), int(p.size)]
    else:
      if i.style == num:
        [int(p.size), int(pos) + int(p.size)]
      else:
        [int(p.size), int(pos) + (4 * p.size)]

  # Create Desktop Image
  if i.style == Indicator.dots:
    if p.pos == top or p.pos == bottom:
      newDesktopImg = hDesktopDotsImg
    else:
      newDesktopImg = vDesktopDotsImg
  elif i.style == Indicator.numbers:
    if p.pos == top or p.pos == bottom:
      newDesktopImg = hDesktopNumbersImg
    else:
      newDesktopImg = vDesktopNumbersImg
  else:
    newDesktopImg = desktopNumImg

  let img = newDesktopImg(getCurrentWS())

  # Create callbacks

  # Create widget
  var widget: Widget = Widget(widgetType: desktop, startPos: startPos, endPos: endPos, img: img)

  return widget

# ========================================================================================
#
#                                   Leve Panel
#                                 Desktop Widget
#
# ========================================================================================

proc hDesktopDotsImg(curWS: int): Image =
  let img = newImage(p.size * 4, p.size)
  let centerX: float32 = float32(p.size * 2)
  let numCircles: int = getNumWorkspaces()
  let radius: int = p.size div 10
  let color = rgba(255, 255, 255, 255)
  let ctx = img.newContext()
  ctx.fillStyle = color

  # Row configuration
  let gap: int = 10 # Gap between circles
  let rowWidth: int = (numCircles * radius * 2) + (gap * (numCircles - 1))
  let startX: float32 = centerX - (rowWidth / 2) + float32(radius)

  for i in 0 ..< workspaces.len:
    let posX = startX + float32(i * (radius * 2 + gap))
    let posY = p.size / 2

    if workspaces[i].num == curWS:
      ctx.fillCircle(circle(vec2(posX, posY), float32(radius + 2)))
    else:
      ctx.fillCircle(circle(vec2(posX, posY), float32(radius)))

  return img

proc vDesktopDotsImg(curWS: int): Image =
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

  for i in 0 ..< workspaces.len:
    let posX = p.size / 2
    let posY = startX + float32(i * (radius * 2 + gap))

    if workspaces[i].num == curWS:
      ctx.fillCircle(circle(vec2(posX, posY), float32(radius + 2)))
    else:
      ctx.fillCircle(circle(vec2(posX, posY), float32(radius)))

  return img

proc hDesktopNumbersImg(curWS: int): Image =
  let img = newImage(p.size * 4, p.size)
  var text = ""

  for workspace in workspaces:
    if workspace.num == curWS:
      text = text & "[" & $workspace.num & "]"
    else:
      text = text & "\xA0" & $workspace.num & "\xA0"

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

proc vDesktopNumbersImg(curWS: int): Image =
  let img = newImage(p.size, p.size * 4)
  var text = ""

  for workspace in workspaces:
    if workspace.num == curWS:
      text = text & "[" & $workspace.num & "]" & "\n"
    else:
      text = text & "\xA0" & $workspace.num & "\xA0" & "\n"

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

proc desktopNumImg(curWS: int): Image =
  let img = newImage(p.size, p.size)
  let text = $curWS

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

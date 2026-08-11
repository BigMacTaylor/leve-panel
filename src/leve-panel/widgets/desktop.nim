# ========================================================================================
#
#                                   Leve Panel
#                                 Desktop Widget
#
# ========================================================================================

proc hDesktopDotsImg(w: ptr Widget, curWS: int) =
  let centerX: float32 = float32(p.size * 2)
  let numCircles: int = getNumWorkspaces()
  let radius: int = p.size div 10
  let color = rgba(255, 255, 255, 255)
  let ctx = w.img.newContext()
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

proc vDesktopDotsImg(w: ptr Widget, curWS: int) =
  let centerX: float32 = float32(p.size * 2)
  let numCircles: int = getNumWorkspaces()
  let radius: int = p.size div 10
  let color = rgba(255, 255, 255, 255)
  let ctx = w.img.newContext()
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

proc hDesktopNumbersImg(w: ptr Widget, curWS: int) =
  var text = ""

  for workspace in workspaces:
    if workspace.num == curWS:
      text = text & "[" & $workspace.num & "]"
    else:
      text = text & "\xA0" & $workspace.num & "\xA0"

  # Draw Text
  font.size = 15
  font.paint.color = color(1, 1, 1) # White

  # Center text both horizontally and vertically
  let layout = font.typeset(
    text,
    bounds = vec2(w.img.width.float, w.img.height.float),
    hAlign = CenterAlign,  # Horizontal: Left, Center, Right
    vAlign = MiddleAlign   # Vertical: Top, Middle, Bottom
  )

  # Draw the text within the specified bounds, centered
  w.img.fillText(layout, translate(vec2(0, 0)))

proc vDesktopNumbersImg(w: ptr Widget, curWS: int) =
  var text = ""

  for workspace in workspaces:
    if workspace.num == curWS:
      text = text & "[" & $workspace.num & "]" & "\n"
    else:
      text = text & "\xA0" & $workspace.num & "\xA0" & "\n"

  # Draw Text
  font.size = 15
  font.paint.color = color(1, 1, 1) # White

  # Center text both horizontally and vertically
  let layout = font.typeset(
    text,
    bounds = vec2(w.img.width.float, w.img.height.float),
    hAlign = CenterAlign,  # Horizontal: Left, Center, Right
    vAlign = MiddleAlign   # Vertical: Top, Middle, Bottom
  )

  # Draw the text within the specified bounds, centered
  w.img.fillText(layout, translate(vec2(0, 0)))

proc desktopNumImg(w: ptr Widget, curWS: int) =
  let text = $curWS
  font.size = 15
  font.paint.color = color(1, 1, 1) # White

  # Center text both horizontally and vertically
  let layout = font.typeset(
    text,
    bounds = vec2(w.img.width.float, w.img.height.float),
    hAlign = CenterAlign,  # Horizontal: Left, Center, Right
    vAlign = MiddleAlign   # Vertical: Top, Middle, Bottom
  )

  # Draw the text within the specified bounds, centered
  w.img.fillText(layout, translate(vec2(0, 0)))

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

  let horizontal = p.pos == top or p.pos == bottom

  # Create Image Proc
  drawDesktopImg = case i.style
    of Indicator.dots:
      if horizontal: hDesktopDotsImg else: vDesktopDotsImg
    of Indicator.numbers:
      if horizontal: hDesktopNumbersImg else: vDesktopNumbersImg
    else:
      desktopNumImg

  # Create Image
  let img = if (i.style == Indicator.num):
    newImage(p.size, p.size)
  else:
    if horizontal:
      newImage(p.size * 4, p.size)
    else:
      newImage(p.size, p.size * 4)

  # Create callbacks

  # Create widget
  var widget: Widget = Widget(
    widgetType: desktop,
    startPos: startPos,
    endPos: endPos,
    img: img,
  )

  drawDesktopImg(addr widget, getCurrentWS())

  return widget

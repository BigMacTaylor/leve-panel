# ========================================================================================
#
#                                   Leve Panel
#                                  Clock Widget
#
# ========================================================================================

proc getClockTT(): string =
  let now = now()
  let text = now.format("dddd, MMMM d")

  return text

proc getTime(): string =
  let now = now()
  let time = now.format("h:mm tt")

  return time

proc getDateTime(): string =
  let now = now()
  let time = now.format("h:mm tt")
  let date = now.format("MM/d/YYYY")

  return time & "\n" & date

proc onClock(data: pointer, item: PanelItem) =
  debug "open clock widget"
  exec(item)

proc drawClockImg(w: ptr Widget) =
  let text = if useDateTime:
      font.size = 15; getDateTime()
    else:
      font.size = 18; getTime()

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

proc newClockWidget(item: PanelItem, pos: float32): Widget =
  let startPos: array[2, int] =
    if p.pos == top or p.pos == bottom:
      [int(pos), 0]
    else:
      [0, int(pos)]

  let endPos: array[2, int] =
    if p.pos == top or p.pos == bottom:
      [int(pos) + (2 * p.size), int(p.size)]
    else:
      [int(p.size), int(pos) + (2 * p.size)]

  useDateTime = (item.style == modern)

  # Create Image
  let img = 
    if p.pos == top or p.pos == bottom:
      newImage(p.size * 2, p.size)
    else:
      newImage(p.size, p.size * 2)

  # Create callbacks
  let click: CallBack = (Event.click_l, proc(data: pointer) = onClock(data, item))
  let callBacks: seq[CallBack] = @[click]

  # Create widget
  let widget: Widget = Widget(
    widgetType: clock,
    startPos: startPos,
    endPos: endPos,
    img: img,
    callBacks: callBacks,
  )

  drawClockImg(addr widget)

  return widget

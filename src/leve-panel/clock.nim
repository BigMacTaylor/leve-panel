# ========================================================================================
#
#                                   Leve Panel
#                                  Clock Widget
#
# ========================================================================================

# Callback function to update the label
proc getTime(): string =
  let now = now()
  let time = now.format("h:mm tt")
  let date = now.format("MM/d/YYYY")

  return time & "\n" & date

proc onClock(data: pointer) =
  echo "open clock widget"
  exec(cast[ptr PanelItem](data))

proc newClockImg(): Image =
  let img = 
    if p.pos == top or p.pos == bottom:
      newImage(p.size * 2, p.size)
    else:
      newImage(p.size, p.size * 2)
  let text = getTime()

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

proc newClockWidget(i: PanelItem, pos: float32): Widget =
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

  # Create Clock Image
  let img = newClockImg()

  # Create callbacks
  let click: CallBack = (Event.click_l, proc(data: pointer) = onClock(addr i))
  let callBacks: seq[CallBack] = @[click]

  # Create widget
  let widget: Widget = Widget(widgetType: clock, startPos: startPos, endPos: endPos, img: img, callBacks: callBacks)

  return widget


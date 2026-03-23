# ========================================================================================
#
#                                   Leve Panel
#                                  Clock widget
#
# ========================================================================================

import times

# Callback function to update the label
proc getTime(): string =
  let now = now()
  let time = now.format("h:mm tt")
  let date = now.format("MM/d/YYYY")

  return time & "\n" & date

proc onClock(data: pointer) =
  echo "open clock"

proc newClockWidget(startPos: array[2, int], endPos: array[2, int]): Widget =
  # Create clock
  let clock = newImage(p.size * 2, p.size)
  let text = getTime()

  # Draw Text
  let font = readFont("Roboto-Regular.ttf")
  font.size = 15
  font.paint.color = color(1, 1, 1) # White

  # Center text both horizontally and vertically
  let layout = font.typeset(
    text,
    bounds = vec2(clock.width.float, clock.height.float),
    hAlign = CenterAlign,  # Horizontal: Left, Center, Right
    vAlign = MiddleAlign   # Vertical: Top, Middle, Bottom
  )

  # Draw the text within the specified bounds, centered
  clock.fillText(layout, translate(vec2(0, 0)))
  #clock.fillText(font.typeset(text, vec2(180, 180)), translate(vec2(0, 0)))

  # Create callbacks
  let click: CallBack = ("click_l", onClock)
  let callBacks: seq[CallBack] = @[click]

  # Create widget
  let widget: Widget = Widget(startPos: startPos, endPos: endPos, img: clock, callBacks: callBacks)

  return widget


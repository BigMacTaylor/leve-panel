# ========================================================================================
#
#                                   Leve Panel
#                                  Status Widget
#
# ========================================================================================



proc newFont(typeface: Typeface, size: float32, color: Color): Font =
  result = newFont(typeface)
  result.size = size
  result.paint.color = color



# Callback function to update the label
proc getStatusText(cmd: string): string =
  let now = now()
  let time = now.format("h:mm tt")
  let date = now.format("MM/d/YYYY")

  let cmd = """vmstat 1 2 | tail -1 | awk '{print $15}' """
  let (output, status) = execCmdEx(cmd)

  if status != 0:
    echo "Error: Could not get mute status"
    return "Error"

  var num = output.strip.parseInt
  num = num div 10


  return $num & "%"

proc onStatusBtn(data: pointer) =
  echo "power off menu "
  exec(cast[ptr PanelItem](data))

proc newStatusImg(cmd: string): Image =
  # Create image
  let img = newImage(p.size, p.size)

  let text = "Vol:" & getStatusText(cmd)
  echo text
  # Draw Text
  let font = try:
    #readFont(fontPath)
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
  #img.fillText(typeset(spans, vec2(180, 180)), translate(vec2(10, 10)))

  return img

proc newStatusImgBak(cmd: string): Image =
  # Create image
  let img = newImage(p.size, p.size)

  let text = getStatusText(cmd)

  # Draw Text
  let typeface = try:
    #readFont(fontPath)
    readTypeface(fontPath)
  except:
    fontPath = getFont()
    readTypeface(fontPath)
  #font.size = 15
  #font.paint.color = color(1, 1, 1) # White


  let spans = @[
    newSpan("str", newFont(typeface, 14, color(1, 1, 1, 1))),
    newSpan("all", newFont(typeface, 14, color(0, 0.5, 0.953125, 1))),
    newSpan("ow", newFont(typeface, 14, color(1, 1, 1, 1)))
  ]


#[
  # Center text both horizontally and vertically
  let layout = font.typeset(
    text,
    bounds = vec2(img.width.float, img.height.float),
    hAlign = CenterAlign,  # Horizontal: Left, Center, Right
    vAlign = MiddleAlign   # Vertical: Top, Middle, Bottom
  )
]#

  # Draw the text within the specified bounds, centered
  #img.fillText(layout, translate(vec2(0, 0)))
  img.fillText(typeset(spans, vec2(180, 180)), translate(vec2(10, 10)))

  return img

proc newStatusWidget(i: PanelItem, pos: float32): Widget =
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

  # Create Power Image
  let img = newStatusImg(i.exec)

  # Create callbacks
  let click: CallBack = (Event.click_l, proc(data: pointer) = onStatusBtn(addr i))
  let callBacks: seq[CallBack] = @[click]

  # Create widget
  var widget: Widget = Widget(widgetType: status, startPos: startPos, endPos: endPos, img: img, exec: i.exec, callBacks: callBacks)

  return widget


# ========================================================================================
#
#                                   Leve Panel
#                                   Mem Widget
#
# ========================================================================================

type
  MemStats = object
    totalKb: int
    availableKb: int
    usedPercent: float

proc getMemoryStats(): MemStats =
  ## Parses /proc/meminfo to extract total and available RAM
  let lines = readFile("/proc/meminfo").splitLines()
  
  for line in lines:
    let fields = line.splitWhitespace()
    if fields.len >= 2:
      if fields[0] == "MemTotal:":
        result.totalKb = parseInt(fields[1])
      elif fields[0] == "MemAvailable:":
        result.availableKb = parseInt(fields[1])
        
  if result.totalKb > 0:
    let usedKb = result.totalKb - result.availableKb
    result.usedPercent = (usedKb.float / result.totalKb.float) * 100.0
  else:
    raise newException(ValueError, "Failed to parse /proc/meminfo metrics")

proc getMemText(): string =
  var mem: MemStats
  try:
    mem = getMemoryStats()
    debug "RAM Usage: ", mem.usedPercent.formatFloat(ffDecimal, 2), "%"
  except Exception as e:
    echo "Error: ", e.msg

  let num = mem.usedPercent.toInt()

  return "Mem\n" & "\xA0\xA0" & $num & "%"

proc onMemBtn(data: pointer) =
  echo "power off menu "
  exec(cast[ptr PanelItem](data))

proc drawMemImg(w: ptr Widget) =
  let ctx = w.img.newContext()

  # Draw widget background
  if w.roundedSide == none:
    w.img.fill(p.color)
  else:
    ctx.roundBgCorners(w.roundedSide, w.img.width.int32, w.img.height.int32)

  # Draw Text
  let text = getMemText()
  let font = try:
    readFont(fontPath)
  except:
    fontPath = getFont()
    readFont(fontPath)
  font.size = 14
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

proc newMemWidget(i: PanelItem, pos: float32, rdSide: Side): Widget =
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
  let click: CallBack = (Event.click_l, proc(data: pointer) = onMemBtn(addr i))
  let callBacks: seq[CallBack] = @[click]

  # Create widget
  var widget: Widget = Widget(
    widgetType: mem,
    startPos: startPos,
    endPos: endPos,
    roundedSide: rdSide,
    img: img,
    callBacks: callBacks,
  )

  drawMemImg(addr widget)

  return widget

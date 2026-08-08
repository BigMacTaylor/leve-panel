# ========================================================================================
#
#                                   Leve Panel
#                                   CPU Widget
#
# ========================================================================================

type CpuTime = object
  user, nice, system, idle, iowait, irq, softirq, steal: int

var cpuTime: CpuTime

proc newFont(typeface: Typeface, size: float32, color: Color): Font =
  result = newFont(typeface)
  result.size = size
  result.paint.color = color

proc getCpuTime(): CpuTime =
  # Reads the first line of /proc/stat
  let lines = readFile("/proc/stat").splitLines()
  if lines.len == 0: return
  
  # The first line starts with "cpu " followed by the metrics
  let fields = lines[0].splitWhitespace()
  if fields.len < 9 or fields[0] != "cpu":
    raise newException(ValueError, "Failed to parse /proc/stat")

  result.user    = parseInt(fields[1])
  result.nice    = parseInt(fields[2])
  result.system  = parseInt(fields[3])
  result.idle    = parseInt(fields[4])
  result.iowait  = parseInt(fields[5])
  result.irq     = parseInt(fields[6])
  result.softirq = parseInt(fields[7])
  result.steal   = parseInt(fields[8])

proc calculateCpuPercent(t1, t2: CpuTime): float =
  # Calculate totals
  let prevIdle = t1.idle + t1.iowait
  let idle = t2.idle + t2.iowait

  let prevNonIdle = t1.user + t1.nice + t1.system + t1.irq + t1.softirq + t1.steal
  let nonIdle = t2.user + t2.nice + t2.system + t2.irq + t2.softirq + t2.steal

  let prevTotal = prevIdle + prevNonIdle
  let total = idle + nonIdle

  # Diffs
  let totalDiff = total - prevTotal
  let idleDiff = idle - prevIdle

  if totalDiff == 0: return 0.0
  
  # Percentage formula
  result = (totalDiff - idleDiff).float / totalDiff.float * 100.0

# Callback function to update the label
proc getCpuText(): string =
  var usage: float
  try:
    let t1 = cpuTime
    let t2 = getCpuTime()
    cpuTime = t2

    usage = calculateCpuPercent(t1, t2)
    echo "Current CPU Usage: ", usage.formatFloat(ffDecimal, 2), "%"
  except Exception as e:
    echo "Error: ", e.msg

  let num = usage.toInt()

  return "CPU\n" & "\xA0\xA0" & $num & "%"

proc getCpuTextBak(cmd: string): string =
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

proc onCpuBtn(data: pointer) =
  echo "power off menu "
  exec(cast[ptr PanelItem](data))

proc drawCpuImg(w: ptr Widget) =
  let ctx = w.img.newContext()

  # Draw widget background
  if w.roundedSide == none:
    w.img.fill(p.color)
  else:
    ctx.roundBgCorners(w.roundedSide, w.img.width.int32, w.img.height.int32)

  let iconSize = if p.iconSize > 24:
    p.iconSize - 2
  else:
    p.iconSize

  let padding = (p.size - p.iconSize) / 2

  # Draw Text
  let text = getCpuText()
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

proc newCpuWidget(i: PanelItem, pos: float32): Widget =
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
  let click: CallBack = (Event.click_l, proc(data: pointer) = onCpuBtn(addr i))
  let callBacks: seq[CallBack] = @[click]

  # Create widget
  var widget: Widget = Widget(widgetType: cpu, startPos: startPos, endPos: endPos, roundedSide: Side.none, img: img, callBacks: callBacks)
  drawCpuImg(addr widget)

  return widget

# ========================================================================================
#
#                                   Leve Panel
#                                   Favorites
#
# ========================================================================================

proc notFoundIcon(): Image =
  let icon = newImage(p.size, p.size)
  let text = "Icon not found"
  font.size = 15
  font.paint.color = color(1, 1, 1) # White

  # Center text both horizontally and vertically
  let layout = font.typeset(
    text,
    bounds = vec2(icon.width.float, icon.height.float),
    hAlign = CenterAlign,  # Horizontal: Left, Center, Right
    vAlign = MiddleAlign   # Vertical: Top, Middle, Bottom
  )
  icon.fillText(layout, translate(vec2(0, 0)))

  return icon

proc trimWhiteSpace(i: Image): Image =
  let image = i

  # Find bounds
  var minX = image.width
  var minY = image.height
  var maxX = 0
  var maxY = 0
  var foundContent = false

  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      let color = image[x, y]
      # Check if pixel is not white (assuming 255,255,255)
      if color.r > 1 or color.g > 1 or color.b > 1:
        foundContent = true
        if x < minX:
          minX = x
        if x > maxX:
          maxX = x
        if y < minY:
          minY = y
        if y > maxY:
          maxY = y

  # Crop the image
  if foundContent:
    let
      width = maxX - minX + 1
      height = maxY - minY + 1
      cropped = image.subImage(minX, minY, width, height)
    return cropped
  else:
    return i

proc getStateIconPath(subsystem: string, state: WidgetState): string =
  ## Returns the absolute file path for an icon based on the subsystem and its structural WidgetState.
  var iconName: string

  case subsystem.toLowerAscii()
  of "volume":
    case state
    of WidgetState.off:     iconName = "audio-volume-muted-symbolic.png"
    of WidgetState.low:     iconName = "audio-volume-low-symbolic.png"
    of WidgetState.med:     iconName = "audio-volume-medium-symbolic.png"
    of WidgetState.high:    iconName = "audio-volume-high-symbolic.png"
    of WidgetState.special: iconName = "audio-volume-high-symbolic.png" # Fallback if ever triggered

  of "wifi":
    case state
    of WidgetState.off:     iconName = "network-offline-symbolic.png"
    of WidgetState.low:     iconName = "network-wireless-signal-weak-symbolic.png" # Or ok-symbolic
    of WidgetState.med:     iconName = "network-wireless-signal-good-symbolic.png"
    of WidgetState.high:    iconName = "network-wireless-signal-excellent-symbolic.png"
    of WidgetState.special: iconName = "network-wireless-signal-excellent-symbolic.png"

  of "ethernet":
    case state
    of WidgetState.off:     iconName = "network-offline-symbolic.png"
    of WidgetState.low:     iconName = "network-wireless-signal-weak-symbolic.png" # Or ok-symbolic
    of WidgetState.med:     iconName = "network-wireless-signal-good-symbolic.png"
    of WidgetState.high:    iconName = "network-wireless-signal-excellent-symbolic.png"
    of WidgetState.special: iconName = "network-wired-symbolic.png" # Useful placeholder for ethernet override

  of "battery":
    case state
    of WidgetState.off:     iconName = "battery-caution-symbolic.png"     # Critical/Empty
    of WidgetState.low:     iconName = "battery-low-symbolic.png"
    of WidgetState.med:     iconName = "battery-good-symbolic.png"        # Or medium-symbolic
    of WidgetState.high:    iconName = "battery-full-symbolic.png"
    of WidgetState.special: iconName = "battery-charging-symbolic.png"    # Connected to power

  else:
    iconName = "image-missing-symbolic.png" # Generic fallback asset

  # Match your existing project path resolution logic
  result = getConfigDir() / "icons" / iconName
  if not fileExists(result):
    result = "/usr/share/leve-panel/icons" / iconName

proc exec(data: PanelItem) =
  var cmd = data.exec

  # Trim '%' and everything afterwards
  if '%' in cmd:
    cmd = cmd.split('%')[0]

  if not data.terminal:
    discard execShellCmd(cmd & " &")
    return

  # If terminal
  let terminal = getEnv("TERMINAL")
  if terminal != "":
    cmd = terminal & "-e " & cmd
  elif fileExists("/etc/alternatives/x-terminal-emulator"):
    cmd = "/etc/alternatives/x-terminal-emulator -e " & cmd
  else:
    cmd = "foot " & cmd

  discard execShellCmd(cmd & " &")

proc onFavClick(data: pointer, item: PanelItem) =
  debug "fav click"
  exec(item)

proc drawFavImg(w: ptr Widget, fav: PanelItem) =
  let padding = (p.size - p.iconSize) / 2

  # Load Icon
  var icon: Image
  if fav.icon.endsWith(".png"):
    echo "Load icon: ", fav.icon
    icon = try:
      readImage(fav.icon)
    except:
      echo "Error: Icon not found"
      notFoundIcon()
  elif fav.icon.endsWith(".svg"):
    echo "Load icon: ", fav.icon
    echo "svg block"
    icon = try:
      readImage(fav.icon)
    except:
      echo "Error: Icon not found"
      notFoundIcon()

    w.img.draw(
      icon,
      translate(vec2(100, 100)) * scale(vec2(0.2, 0.2)) * translate(vec2(-450, -450)),
    )
  else:
    echo "Error: Icon not found"
    icon = notFoundIcon()

  # Remove whitespace 
  icon = icon.trimWhiteSpace()

  # Resize Icon
  let sizedIcon = icon.resize(p.iconSize, p.iconSize)
  w.img.draw(sizedIcon, translate(vec2(padding.float32, padding.float32)))

proc newFavWidget(item: PanelItem, pos: float32): Widget =
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
  let click: CallBack = (Event.click_l, proc(data: pointer) = onFavClick(data, item))
  let callBacks: seq[CallBack] = @[click]

  # Create widget
  let widget: Widget = Widget(
    widgetType: favorite,
    startPos: startPos,
    endPos: endPos,
    img: img,
    callBacks: callBacks,
  )

  drawFavImg(addr widget, item)

  return widget

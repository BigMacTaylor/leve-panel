# ========================================================================================
#
#                                   Leve Panel
#                                   Favorites
#
# ========================================================================================

proc notFoundIcon(): Image =
  let icon = newImage(p.size, p.size)
  # Draw Text
  let text = "Icon not found"
  let font = readFont("Roboto-Regular.ttf")
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

proc exec(fav: ptr PanelItem) =
  var cmd = fav.exec

  # Trim '%' and everything afterwards
  if '%' in cmd:
    cmd = cmd.split('%')[0]

  if not fav.terminal:
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

proc onFavClick(fav: pointer) =
  echo "on click"
  exec(cast[ptr PanelItem](fav))
  #echo new.name

proc newFavWidget(fav: PanelItem, startPos: array[2, int], endPos: array[2, int]): Widget =
  let padding = (p.size - p.iconSize) / 2

  # Create button
  let button = newImage(p.size, p.size)

  var icon: Image

  # Load Icon
  if fav.icon.endsWith(".png"):
    icon = try:
      readImage(fav.icon)
    except:
      echo "Error: Icon not found"
      notFoundIcon()
  elif fav.icon.endsWith(".svg"):
    echo "svg block"
    icon = try:
      readImage(fav.icon)
    except:
      echo "Error: Icon not found"
      notFoundIcon()


    button.draw(
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
  button.draw(sizedIcon, translate(vec2(padding.float32, padding.float32)))

  # Create callbacks
  let click: CallBack = ("click_l", proc(data: pointer) = onFavClick(addr fav))
  let callBacks: seq[CallBack] = @[click]

  # Create widget
  let widget: Widget = Widget(startPos: startPos, endPos: endPos, img: button, callBacks: callBacks)

  return widget

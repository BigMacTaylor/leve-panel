import json



proc getCurrentSwayWorkspace(): string =
  # 1. Execute swaymsg to get workspaces in JSON format
  let (output, exitCode) = execCmdEx("swaymsg -t get_workspaces")
  
  if exitCode != 0:
    return "Error: Could not connect to sway"

  # 2. Parse JSON
  let workspaces = parseJson(output)
  
  # 3. Iterate to find the focused workspace
  for workspace in workspaces:
    if workspace["focused"].getBool():
      return workspace["name"].getStr()

  return "None"

proc newDesktopImg(): Image =
  let img = newImage(p.size * 2, p.size)
  let text = getCurrentSwayWorkspace()

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



proc newDesktopWidget(startPos: array[2, int], endPos: array[2, int]): Widget =
  # Create volume Image
  let icon = newDesktopImg()

  # Create callbacks

  # Create widget
  var widget: Widget = Widget(widgetType: WidgetType.desktop, startPos: startPos, endPos: endPos, img: icon)

  return widget

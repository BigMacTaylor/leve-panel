import json



proc getCurrentSwayWorkspace(): string =
  let (output, exitCode) = execCmdEx("swaymsg -t get_workspaces")
  
  if exitCode != 0:
    return "Error: Could not connect to sway"

  let workspaces = parseJson(output)
  
  # Find focused workspace
  for workspace in workspaces:
    if workspace["focused"].getBool():
      return workspace["name"].getStr()

  return "None"

proc getNumSwayWorkspaces(): string =
  let (output, exitCode) = execCmdEx("swaymsg -t get_workspaces")
  
  if exitCode != 0:
    return "Error: Could not connect to sway"

  let json = parseJson(output)
  var workspaces = 0

  for workspace in json:
    workspaces = workspaces + 1

  return $workspaces

proc desktopDotsImg(): Image =
  let img = newImage(p.size * 2, p.size)
  let curWS = getCurrentSwayWorkspace()
  let numWS = getNumSwayWorkspaces()

  let text = curWS & " - " & numWS

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

proc desktopNumImg(): Image =
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
  #if p.desktop_indicator == Indicator.dots:
  if false:
    newDesktopImg = desktopDotsImg
  else:
    newDesktopImg = desktopNumImg
  let icon = newDesktopImg()

  # Create callbacks

  # Create widget
  var widget: Widget = Widget(widgetType: WidgetType.desktop, startPos: startPos, endPos: endPos, img: icon)

  return widget

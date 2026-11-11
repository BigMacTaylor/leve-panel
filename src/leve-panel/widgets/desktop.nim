# ========================================================================================
#
#                                   Leve Panel
#                                 Desktop Widget
#
# ========================================================================================

proc desktopNumImg(w: ptr Widget, curWS: int) =
  let text = $getCurrentWS()
  font.size = 15
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

# ----------------------------------------------------------------------------------------
#                                    Dots
# ----------------------------------------------------------------------------------------

proc hDesktopDotImg(w: ptr Widget, curWS: int) =
  let panelSize = int32(p.size)
  let centerX = panelSize * 2
  let radius = panelSize div 10
  let ctx = w.img.newContext()
  ctx.fillStyle = rgba(255, 255, 255, 255)

  # Row configuration
  let numBtns = int32(getNumWorkspaces())
  let gap: int32 = 10 # Gap between dots
  let rowWidth = (numBtns * radius * 2) + (gap * (numBtns - 1))
  let startX = centerX - (rowWidth div 2) + radius
  let posY = panelSize div 2

  var dotPos: int32 = 0

  # Clear the old button positions
  w.buttons.setLen(0)

  for ws in workspaces:
    if hidden notin ws.state:
      let posX = startX + (dotPos * (radius * 2 + gap))
      dotPos.inc

      # Calculate the clickable area for each button
      let currentRadius = if active in ws.state: radius + 2 else: radius
      let clickPadding: int32 = 4 # Padding to make small dots easier to click
      let xStart = posX - (currentRadius + clickPadding)
      let xEnd = posX + (currentRadius + clickPadding)
      let yStart = posY - (currentRadius + clickPadding)
      let yEnd = posY + (currentRadius + clickPadding)

      # Store either the workspace handle or number(for Sway IPC)
      let wsData = if useSwayIPC: cast[pointer](ws.num) else: ws.handle

      # Add button positions to widget
      w.buttons.add(Button(
        data: wsData,
        xStart: xStart,
        xEnd: xEnd,
        yStart: yStart,
        yEnd: yEnd,
      ))

      # Draw circle
      ctx.fillCircle(circle(
        vec2(float32(posX), float32(posY)), 
        float32(currentRadius)
      ))

proc vDesktopDotImg(w: ptr Widget, curWS: int) =
  let panelSize = int32(p.size)
  let centerY = panelSize * 2
  let radius = panelSize div 10
  let ctx = w.img.newContext()
  ctx.fillStyle = rgba(255, 255, 255, 255)

  # Row configuration
  let numBtns = int32(getNumWorkspaces())
  let gap: int32 = 10 # Gap between dots
  let rowHeight = (numBtns * radius * 2) + (gap * (numBtns - 1))
  let startY = centerY - (rowHeight div 2) + radius
  let posX = panelSize div 2
  
  var dotPos: int32 = 0

  # Clear the old button positions
  w.buttons.setLen(0)

  for ws in workspaces:
    if hidden notin ws.state:
      let posY = startY + (dotPos * (radius * 2 + gap))
      dotPos.inc

      # Calculate the clickable area for each button
      let currentRadius = if active in ws.state: radius + 2 else: radius
      let clickPadding: int32 = 4 # Padding to make small dots easier to click
      let xStart = posX - (currentRadius + clickPadding)
      let xEnd = posX + (currentRadius + clickPadding)
      let yStart = posY - (currentRadius + clickPadding)
      let yEnd = posY + (currentRadius + clickPadding)

      # Store either the workspace handle or number(for Sway IPC)
      let wsData = if useSwayIPC: cast[pointer](ws.num) else: ws.handle

      # Add button positions to widget
      w.buttons.add(Button(
        data: wsData,
        xStart: xStart,
        xEnd: xEnd,
        yStart: yStart,
        yEnd: yEnd,
      ))

      ctx.fillCircle(circle(
        vec2(float32(posX), float32(posY)), 
        float32(currentRadius)
      ))

# ----------------------------------------------------------------------------------------
#                                    Pills
# ----------------------------------------------------------------------------------------

proc hDesktopPillImg(w: ptr Widget, curWS: int) =
  let totalWidth = int32(w.img.width)
  let totalHeight = int32(w.img.height)
  let ctx = w.img.newContext()
  font.size = 14

  # Button Configuration
  let btnSpace: int32 = 0
  let btnPaddingX: int32 = 4
  let btnPaddingY: int32 = 4

  # Clear the old button positions
  w.buttons.setLen(0)

  # Count visible workspaces and sum up text width
  var numBtns: int32 = 0
  var textWidth: int32 = 0

  for ws in workspaces:
    if hidden notin ws.state:
      numBtns.inc
      let layout = font.typeset($ws.num, bounds = vec2(totalWidth.float, totalHeight.float))
      textWidth += int32(layout.layoutBounds().x)

  if numBtns == 0: return

  # Calculate total width of buttons
  let totalSpace = btnSpace * (numBtns - 1)
  let totalPadding = numBtns * (btnPaddingX * 2)
  let totalBtnWidth = textWidth + totalSpace + totalPadding
  
  # Calculate starting position for buttons
  var btnPosX = (totalWidth - totalBtnWidth) div 2

  # Draw button for each visible workspace
  for ws in workspaces:
    if hidden notin ws.state:
      let isActive = active in ws.state
      let label = $ws.num

      # Calculate text geometry
      let layout = font.typeset(label, bounds = vec2(totalWidth.float, totalHeight.float))
      let textBounds = layout.layoutBounds()
      let textWidth = int32(textBounds.x)
      let textHeight = int32(textBounds.y)

      # Calculate the clickable area for each button
      let startY = (totalHeight - textHeight) div 2
      let btnPosY = startY - btnPaddingY
      let btnWidth  = textWidth + (btnPaddingX * 2)
      let btnHeight = textHeight + (btnPaddingY * 2)

      # Draw active background BEFORE drawing text layer
      if isActive:
        ctx.fillStyle = rgba(255, 255, 255, 40) # Subtle white (15% opacity)
        ctx.fillRoundedRect(
          rect(btnPosX.float, btnPosY.float, btnWidth.float, btnHeight.float),
          4.0 # Corner roundness radius
        )

      # Store either the workspace handle or number(for Sway IPC)
      let wsData = if useSwayIPC: cast[pointer](ws.num) else: ws.handle

      # Add button positions to widget
      w.buttons.add(Button(
        data: wsData,
        xStart: btnPosX,
        xEnd: btnPosX + btnWidth,
        yStart: btnPosY,
        yEnd: btnPosY + btnHeight,
      ))

      # Draw the text over the background
      font.paint.color = if isActive: color(1, 1, 1) else: color(0.6, 0.6, 0.6)
      w.img.fillText(layout, translate(vec2((btnPosX + btnPaddingX).float, startY.float)))

      btnPosX += btnWidth + btnSpace

proc vDesktopPillImg(w: ptr Widget, curWS: int) =
  let totalWidth = int32(w.img.width)
  let totalHeight = int32(w.img.height)
  let ctx = w.img.newContext()
  font.size = 14

  # Button Configuration
  let btnSpace: int32 = 0
  let btnPaddingX: int32 = 8  # Slightly wider horizontal padding looks better on side bars
  let btnPaddingY: int32 = 1

  # Clear the old button positions
  w.buttons.setLen(0)

  # Count visible workspaces and sum up text height
  var numBtns: int32 = 0
  var textHeight: int32 = 0

  for ws in workspaces:
    if hidden notin ws.state:
      numBtns.inc
      let layout = font.typeset($ws.num, bounds = vec2(totalWidth.float, totalHeight.float))
      textHeight += int32(layout.layoutBounds().y)

  if numBtns == 0: return

  # Calculate total vertical height of the button strip
  let totalSpace = btnSpace * (numBtns - 1)
  let totalPadding = numBtns * (btnPaddingY * 2)
  let totalBtnHeight = textHeight + totalSpace + totalPadding
  
  # Calculate starting vertical position for the group string
  var btnPosY = (totalHeight - totalBtnHeight) div 2

  # Draw button for each visible workspace
  for ws in workspaces:
    if hidden notin ws.state:
      let isActive = active in ws.state
      let label = $ws.num

      # Calculate text geometry
      let layout = font.typeset(label, bounds = vec2(totalWidth.float, totalHeight.float))
      let textBounds = layout.layoutBounds()
      let textWidth = int32(textBounds.x)
      let textHeight = int32(textBounds.y)

      # Calculate the clickable area for each button (Flipped axis logic)
      let startX = (totalWidth - textWidth) div 2
      let btnPosX = startX - btnPaddingX
      let btnWidth  = textWidth + (btnPaddingX * 2)
      let btnHeight = textHeight + (btnPaddingY * 2)

      # Draw active background BEFORE drawing text layer
      if isActive:
        ctx.fillStyle = rgba(255, 255, 255, 40) # Subtle white (15% opacity)
        ctx.fillRoundedRect(
          rect(btnPosX.float, btnPosY.float, btnWidth.float, btnHeight.float),
          4.0 # Corner roundness radius
        )

      # Store either the workspace handle or number(for Sway IPC)
      let wsData = if useSwayIPC: cast[pointer](ws.num) else: ws.handle

      # Add button positions to widget
      w.buttons.add(Button(
        data: wsData,
        xStart: btnPosX,
        xEnd: btnPosX + btnWidth,
        yStart: btnPosY,
        yEnd: btnPosY + btnHeight,
      ))

      # Draw the text over the background background sheet
      font.paint.color = if isActive: color(1, 1, 1) else: color(0.6, 0.6, 0.6)
      w.img.fillText(layout, translate(vec2(startX.float, (btnPosY + btnPaddingY).float)))

      btnPosY += btnHeight + btnSpace

# ----------------------------------------------------------------------------------------
#                                    Numbers
# ----------------------------------------------------------------------------------------

proc hDesktopNumbersImg(w: ptr Widget, curWS: int) =
  let totalWidth = int32(w.img.width)
  let totalHeight = int32(w.img.height)
  font.size = 15

  # Button Configuration
  let btnSpace: int32 = 8

  # Clear the old button positions
  w.buttons.setLen(0)

  # Count visible workspaces and sum up text width
  var numBtns: int32 = 0
  var textWidth: int32 = 0

  for ws in workspaces:
    if hidden notin ws.state:
      numBtns.inc
      let layout = font.typeset($ws.num, bounds = vec2(totalWidth.float, totalHeight.float))
      textWidth += int32(layout.layoutBounds().x)

  if numBtns == 0: return

  # Calculate total width of buttons
  let totalSpace = btnSpace * (numBtns - 1)
  let totalBtnWidth = textWidth + totalSpace

  # Calculate starting position for buttons
  var btnPosX = (totalWidth - totalBtnWidth) div 2

  # Draw button for each visible workspace
  for ws in workspaces:
    if hidden notin ws.state:
      let isActive = active in ws.state
      let label = $ws.num

      # Calculate text geometry
      let layout = font.typeset(label, bounds = vec2(totalWidth.float, totalHeight.float))
      let textBounds = layout.layoutBounds()
      let textWidth = int32(textBounds.x)
      let textHeight = int32(textBounds.y)

      # Vertically center text block
      let startY = (totalHeight - textHeight) div 2

      # Store either the workspace handle or number(for Sway IPC)
      let wsData = if useSwayIPC: cast[pointer](ws.num) else: ws.handle

      # Add button positions to widget
      w.buttons.add(Button(
        data: wsData,
        xStart: btnPosX,
        xEnd: btnPosX + textWidth,
        yStart: startY,
        yEnd: startY + textHeight,
      ))

      # Draw the text over the background
      font.paint.color = if isActive: color(1, 1, 1) else: color(0.5, 0.5, 0.5)
      w.img.fillText(layout, translate(vec2(btnPosX.float, startY.float)))

      btnPosX += textWidth + btnSpace

proc vDesktopNumbersImg(w: ptr Widget, curWS: int) =
  let totalWidth = int32(w.img.width)
  let totalHeight = int32(w.img.height)
  font.size = 15

  # Button Configuration
  let btnSpace: int32 = 0

  # Clear the old button positions
  w.buttons.setLen(0)

  # Count visible workspaces and sum up text height
  var numBtns: int32 = 0
  var textHeight: int32 = 0

  for ws in workspaces:
    if hidden notin ws.state:
      numBtns.inc
      let layout = font.typeset($ws.num, bounds = vec2(totalWidth.float, totalHeight.float))
      textHeight += int32(layout.layoutBounds().y)

  if numBtns == 0: return

  # Calculate total vertical height of the button strip
  let totalSpace = btnSpace * (numBtns - 1)
  let totalBtnHeight = textHeight + totalSpace

  # Calculate starting vertical position for buttons
  var btnPosY = (totalHeight - totalBtnHeight) div 2

  # Draw button for each visible workspace
  for ws in workspaces:
    if hidden notin ws.state:
      let isActive = active in ws.state
      let label = $ws.num

      # Calculate text geometry
      let layout = font.typeset(label, bounds = vec2(totalWidth.float, totalHeight.float))
      let textBounds = layout.layoutBounds()
      let textWidth = int32(textBounds.x)
      let currentTextHeight = int32(textBounds.y)

      # Horizontally center the individual text block within the side bar width
      let startX = (totalWidth - textWidth) div 2

      # Store either the workspace handle or number (for Sway IPC)
      let wsData = if useSwayIPC: cast[pointer](ws.num) else: ws.handle

      # Add button positions to widget (Tight 2D box mapping text bounds exactly)
      w.buttons.add(Button(
        data: wsData,
        xStart: startX,
        xEnd: startX + textWidth,
        yStart: btnPosY,
        yEnd: btnPosY + currentTextHeight,
      ))

      # Draw the text at its calculated centered offset coordinates
      font.paint.color = if isActive: color(1, 1, 1) else: color(0.5, 0.5, 0.5)
      w.img.fillText(layout, translate(vec2(startX.float, btnPosY.float)))

      btnPosY += currentTextHeight + btnSpace

# ----------------------------------------------------------------------------------------
#                                    Classic
# ----------------------------------------------------------------------------------------

proc hDesktopClassicImg(w: ptr Widget, curWS: int) =
  let totalWidth = int32(w.img.width)
  let totalHeight = int32(w.img.height)
  font.size = 14

  # Clear the old button positions
  w.buttons.setLen(0)

  var fullText = ""

  for ws in workspaces:
    if hidden notin ws.state:
      if active in ws.state:
        fullText.add("[" & $ws.num & "]")
      else:
        fullText.add("\xA0" & $ws.num & "\xA0")

  let fullLayout = font.typeset(fullText, bounds = vec2(totalWidth.float, totalHeight.float))
  let totalTextBounds = fullLayout.layoutBounds()

  # Calculate total text geometry
  let textHeight = int32(totalTextBounds.y)
  let startY = (totalHeight - textHeight) div 2
  let totalBtnWidth = int32(totalTextBounds.x)

  # Calculate starting position for buttons
  var btnPosX = (totalWidth - totalBtnWidth) div 2

  # Draw button for each visible workspace
  for ws in workspaces:
    if hidden notin ws.state:
      let label = if active in ws.state: "[" & $ws.num & "]"
        else: "\xA0" & $ws.num & "\xA0"

      # Calculate text geometry
      let layout = font.typeset(label, bounds = vec2(totalWidth.float, totalHeight.float))
      let textWidth = int32(layout.layoutBounds().x)

      # Store either the workspace handle or number(for Sway IPC)
      let wsData = if useSwayIPC: cast[pointer](ws.num) else: ws.handle

      # Add new button positions to widget
      w.buttons.add(Button(
        data: wsData,
        xStart: btnPosX,
        xEnd: btnPosX + textWidth,
        yStart: startY,
        yEnd: startY + textHeight,
      ))

      btnPosX += textWidth

  let layout = font.typeset(
    fullText,
    bounds = vec2(totalWidth.float, totalHeight.float),
    hAlign = CenterAlign,
    vAlign = MiddleAlign
  )

  # Draw the text over the background
  font.paint.color = color(1, 1, 1)
  w.img.fillText(layout, translate(vec2(0, 0)))

proc vDesktopClassicImg(w: ptr Widget, curWS: int) =
  let totalWidth = int32(w.img.width)
  let totalHeight = int32(w.img.height)
  font.size = 14

  # Clear the old button positions
  w.buttons.setLen(0)

  # Count visible workspaces and compute total vertical height
  var numBtns: int32 = 0
  var totalBtnHeight: int32 = 0

  for ws in workspaces:
    if hidden notin ws.state:
      numBtns.inc
      let label = if active in ws.state: "[" & $ws.num & "]" else: "\xA0" & $ws.num & "\xA0"
      let layout = font.typeset(label, bounds = vec2(totalWidth.float, totalHeight.float))
      totalBtnHeight += int32(layout.layoutBounds().y)

  if numBtns == 0: return

  # Calculate starting position for buttons
  var btnPosY = (totalHeight - totalBtnHeight) div 2

  var fullText = ""

  # Draw button for each visible workspace
  for ws in workspaces:
    if hidden notin ws.state:
      let isActive = active in ws.state
      let label = if isActive: "[" & $ws.num & "]" else: "\xA0" & $ws.num & "\xA0"

      fullText.add(label & "\n")

      # Calculate text geometry
      let layout = font.typeset(label, bounds = vec2(totalWidth.float, totalHeight.float))
      let bounds = layout.layoutBounds()
      let textWidth = int32(bounds.x)
      let textHeight = int32(bounds.y)

      # Center horizontally across the side panel width
      let startX = (totalWidth - textWidth) div 2

      # Store either the workspace handle or number (for Sway IPC)
      let wsData = if useSwayIPC: cast[pointer](ws.num) else: ws.handle

      # Add new button positions to widget
      w.buttons.add(Button(
        data: wsData,
        xStart: startX,
        xEnd: startX + textWidth,
        yStart: btnPosY,
        yEnd: btnPosY + textHeight,
      ))

      btnPosY += textHeight

  let layout = font.typeset(
    fullText,
    bounds = vec2(totalWidth.float, totalHeight.float),
    hAlign = CenterAlign,
    vAlign = MiddleAlign
  )

  # Draw the text over the background
  font.paint.color = color(1, 1, 1) # Solid White
  w.img.fillText(layout, translate(vec2(0, 0)))

# ----------------------------------------------------------------------------------------
#                                    Callbacks
# ----------------------------------------------------------------------------------------

#proc onWsSwitcher(data: pointer) {.nimcall.} =
proc onWsSwitcher(data: pointer) =
  echo "onWS"
  if data == nil: return
  let w = cast[ptr Widget](data)
  #TODO let w = cast[Widget](data)

  let boxStartX = w.startPos[0]
  let boxStartY = w.startPos[1]
  let currentX = int32(pointerState.x)
  let currentY = int32(pointerState.y)


  for button in w.buttons:
    # Transform button relative bounds into absolute screen space and compare
    let hitX = currentX >= (button.xStart + boxStartX) and currentX <= (button.xEnd + boxStartX)
    let hitY = currentY >= (button.yStart + boxStartY) and currentY <= (button.yEnd + boxStartY)

    #if currentX >= (button.xStart + boxStart) and currentX <= (button.xEnd + boxStart):
    if hitX and hitY:
      # Found the target! Trigger your Wayland/Compositor IPC workspace switch command
      echo "Switching to workspace index: " #, button.workspaceIndex
      # Example IPC invocation:
      #let wsHandle = getWSHandle(button.workspaceIndex)
      if button.data == nil: break

      if useSwayIPC:
        let wsNum = cast[int](button.data)
        echo "Switching to Sway workspace: ", wsNum
        activateSwayWS(wsNum)
      else:
        let wsHandle = cast[ptr ext_workspace_handle_v1](button.data)
        if s.ws_manager != nil:
          s.ws_manager.activateWS(wsHandle)
      
      break # Target found, exit loop immediately

# ----------------------------------------------------------------------------------------
#                                    Widget
# ----------------------------------------------------------------------------------------

proc newDesktopWidget(i: PanelItem, pos: float32): Widget =
  let startPos: array[2, int] =
    if p.pos == top or p.pos == bottom:
      [int(pos), 0]
    else:
      [0, int(pos)]

  let endPos: array[2, int] =
    if p.pos == top or p.pos == bottom:
      if i.style == num:
        [int(pos) + int(p.size), int(p.size)]
      else:
        [int(pos) + (4 * p.size), int(p.size)]
    else:
      if i.style == num:
        [int(p.size), int(pos) + int(p.size)]
      else:
        [int(p.size), int(pos) + (4 * p.size)]

  let horizontal = p.pos == top or p.pos == bottom

  # Create Image Proc
  drawDesktopImg = case i.style
    of Indicator.dots:
      if horizontal: hDesktopDotImg else: vDesktopDotImg
    of Indicator.numbers:
      if horizontal: hDesktopNumbersImg else: vDesktopNumbersImg
    of Indicator.pills:
      if horizontal: hDesktopPillImg else: vDesktopPillImg
    of Indicator.classic:
      if horizontal: hDesktopClassicImg else: vDesktopClassicImg
    else:
      desktopNumImg

  # Create Image
  let img = if (i.style == Indicator.num):
    newImage(p.size, p.size)
  else:
    if horizontal:
      newImage(p.size * 4, p.size)
    else:
      newImage(p.size, p.size * 4)

  # Create callbacks
  var callBacks: seq[CallBack] = @[]
  let gotoWS: CallBack = (Event.click_l, onWsSwitcher)
  callBacks.add(gotoWS)

  # Create widget
  var widget: Widget = Widget(
    widgetType: desktop,
    startPos: startPos,
    endPos: endPos,
    img: img,
    callBacks: callBacks,
  )

  drawDesktopImg(addr widget, getCurrentWS())

  return widget

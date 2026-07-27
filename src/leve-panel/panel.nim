# ========================================================================================
#
#                                   Leve Panel
#                                   Panel Bar
#
# ========================================================================================

proc roundBgCorners(ctx: Context, side: Side, width, height: int32) =
  # Define context dimensions and corner radius
  let w = float32(width)
  let h = float32(height)
  let x = 0.0
  let y = 0.0
  let r = p.radius

  case side
  of top:
    ctx.beginPath()
    ctx.moveTo(x, y + r) 
    ctx.arcTo(x, y, x + r, y, r)
    ctx.lineTo(x + w - r, y) 
    ctx.arcTo(x + w, y, x + w, y + r, r)
    ctx.lineTo(x + w, y + h)
    ctx.lineTo(x, y + h)
    ctx.closePath()

  of bottom:
    ctx.beginPath()
    ctx.moveTo(x, y) 
    ctx.lineTo(x + w, y)
    ctx.lineTo(x + w, y + h - r)
    ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
    ctx.lineTo(x + r, y + h)
    ctx.arcTo(x, y + h, x, y + h - r, r)
    ctx.lineTo(x, y)
    ctx.closePath()

  of left:
    ctx.beginPath()
    ctx.moveTo(x + r, y) 
    ctx.lineTo(x + w, y)
    ctx.lineTo(x + w, y + h)
    ctx.lineTo(x + r, y + h)
    ctx.arcTo(x, y + h, x, y + h - r, r)
    ctx.lineTo(x, y + r)
    ctx.arcTo(x, y, x + r, y, r)
    ctx.closePath()

  of right:
    ctx.beginPath()
    ctx.moveTo(x, y) 
    ctx.lineTo(x + w - r, y)
    ctx.arcTo(x + w, y, x + w, y + r, r)
    ctx.lineTo(x + w, y + h - r)
    ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
    ctx.lineTo(x, y + h)
    ctx.lineTo(x, y)
    ctx.closePath()

  of all:
    ctx.beginPath()
    ctx.moveTo(x, y + r) 
    ctx.arcTo(x, y, x + r, y, r)
    ctx.lineTo(x + w - r, y)
    ctx.arcTo(x + w, y, x + w, y + r, r)
    ctx.lineTo(x + w, y + h - r)
    ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
    ctx.lineTo(x + r, y + h)
    ctx.arcTo(x, y + h, x, y + h - r, r)
    ctx.lineTo(x, y + r)
    ctx.closePath()

  else:
    discard

  # Fill background color
  ctx.fillStyle = parseHtmlColor(p.color)
  ctx.fill()

proc updateWidget(w: ptr Widget) =
  let width = int32(w.endPos[0] - w.startPos[0])
  let height = int32(w.endPos[1] - w.startPos[1])

  # Create new widget image
  let newImgData = newImage(width, height)
  let ctx = newImgData.newContext()

  # Draw widget background
  if w.roundedSide == none:
    newImgData.fill(parseHtmlColor(p.color))
  else:
    ctx.roundBgCorners(w.roundedSide, width, height)

  # Draw widget icon
  ctx.drawImage(w.img, 0, 0)

  # Copy new image to image data
  var dataPos = 0
  var newDataPos = 0

  if p.pos == top or p.pos == bottom:
    dataPos = w.startPos[0]
    for i in 0 ..< height:
      copyMem(p.pixelData[dataPos].addr, newImgData.data[newDataPos].addr, width * 4)
      dataPos = dataPos + p.width
      newDataPos = newDataPos + width
  else:
    dataPos = w.startPos[1] * width
    for i in w.startPos[1] ..< w.endPos[1]:
      copyMem(p.pixelData[dataPos].addr, newImgData.data[newDataPos].addr, width * 4)
      dataPos = dataPos + width
      newDataPos = newDataPos + width

  # Attach and Damage
  p.surface.wl_surface_attach(p.buffer, 0, 0)
  p.surface.wl_surface_damage(int32(w.startPos[0]), int32(w.startPos[1]), width, height)

# ----------------------------------------------------------------------------------------
#                                    Create Widgets
# ----------------------------------------------------------------------------------------

proc createWidget(item: PanelItem, pos: float32): Widget =
  var widget: Widget

  case item.widget
  of WidgetType.favorite:
    widget = newFavWidget(item, pos)
  of WidgetType.clock:
    widget = newClockWidget(item, pos)
  of WidgetType.volume:
    widget = newVolWidget(item, pos)
  of WidgetType.menu:
    widget = newMenuWidget(item, pos)
  of WidgetType.power:
    widget = newPowerWidget(item, pos)
  of WidgetType.desktop:
    widget = newDesktopWidget(item, pos)

  return widget

# ----------------------------------------------------------------------------------------
#                                    Draw Panel
# ----------------------------------------------------------------------------------------

proc drawPanelImg(panel: ptr Panel): Image =
  echo "\nDrawing panel... \n"

  let width = if panel.pos == top or panel.pos == bottom:
      panel.width
    else: panel.size

  let height = if panel.pos == top or panel.pos == bottom:
      panel.size
    else: panel.height

  # Create transparent image
  let img = newImage(width, height)
  img.fill(rgba(0, 0, 0, 0))

  let ctx = img.newContext()

  # Define panel dimensions and corner radius
  let xy = vec2(0, 0)
  let wh = vec2(float32(width), float32(height))
  let r = p.radius

  # Draw the panel background
  ctx.fillStyle = parseHtmlColor(p.color)
  ctx.fillRoundedRect(rect(xy, wh), r)

  # Zero out Widgets to avoid duplicates
  if widgets.len > 0:
    widgets = @[]

  # Add Left Widgets
  var endWidget = true
  var pos: float32 = 0
  let leftItems = panel.getItems("Left")
  for item in leftItems:
    var widget: Widget = createWidget(item, pos)

    if endWidget:
      if panel.pos == top or panel.pos == bottom:
        widget.roundedSide = left
      else:
        widget.roundedSide = top
    endWidget = false

    widgets.add(widget)

    if p.pos == top or p.pos == bottom:
      ctx.drawImage(widget.img, pos, 0)
    else:
      ctx.drawImage(widget.img, 0, pos)

    if item.widget == WidgetType.clock:
      pos = pos + float32(2 * p.size)
    elif (item.widget == WidgetType.desktop) and (item.style != num):
      pos = pos + float32(4 * p.size)
    else:
      pos = pos + float32(p.size)

  # Get pos for Center Items
  var centerItemsSize = 0
  let centerItems = panel.getItems("Center")
  for item in centerItems:
    if item.widget == WidgetType.clock:
      centerItemsSize = centerItemsSize + (2 * p.size)
    elif (item.widget == WidgetType.desktop) and (item.style != num):
      centerItemsSize = centerItemsSize + (4 * p.size)
    else:
      centerItemsSize = centerItemsSize + p.size

  if p.pos == top or p.pos == bottom:
    pos = (width / 2) - float32(centerItemsSize / 2)
  else:
    pos = (height / 2) - float32(centerItemsSize / 2)

  # Add Center Widgets
  for item in centerItems:
    var widget: Widget = createWidget(item, pos)

    widgets.add(widget)

    if p.pos == top or p.pos == bottom:
      ctx.drawImage(widget.img, pos, 0)
    else:
      ctx.drawImage(widget.img, 0, pos)

    if item.widget == WidgetType.clock:
      pos = pos + float32(2 * p.size)
    elif (item.widget == WidgetType.desktop) and (item.style != num):
      pos = pos + float32(4 * p.size)
    else:
      pos = pos + float32(p.size)

  # Get pos for Right Items
  if p.pos == top or p.pos == bottom:
    pos = float32(width - p.size)
  else:
    pos = float32(height - p.size)

  # Add Right Widgets
  endWidget = true
  let rightItems = panel.getItems("Right")
  for item in rightItems:
    if item.widget == WidgetType.clock:
      pos = pos - float32(p.size)
    elif (item.widget == WidgetType.desktop) and (item.style != num):
      pos = pos - float32(3 * p.size)

    var widget: Widget = createWidget(item, pos)

    if endWidget:
      if panel.pos == top or panel.pos == bottom:
        widget.roundedSide = right
      else:
        widget.roundedSide = bottom
    endWidget = false

    widgets.add(widget)

    if p.pos == top or p.pos == bottom:
      ctx.drawImage(widget.img, pos, 0)
    else:
      ctx.drawImage(widget.img, 0, pos)

    pos = pos - float32(p.size)

  return img

# ----------------------------------------------------------------------------------------
#                                    Configure Surface
# ----------------------------------------------------------------------------------------

proc surfaceClose(
    data: pointer,
    surface: ptr zwlr_layer_surface_v1,
) {.cdecl.} =

  echo "[Surface] Closed by compositor"

  # Generally, you must destroy the surface and the wl_surface
  #zwlr_layer_surface_v1_destroy(layerSurface)
  # Note: You should also destroy the underlying wl_surface here
  # if it was created specifically for this layer surface.

proc configureSurface(
    data: pointer,
    surface: ptr zwlr_layer_surface_v1,
    serial: uint32,
    width: uint32,
    height: uint32,
) {.cdecl.} =
  echo "[Surface] Configure event"

  surface.zwlr_layer_surface_v1_ack_configure(serial)

  if displayInfo.changed == false:
    return

  displayInfo.changed = false

  if p.buffer != nil:
    echo "Redraw panel"

  # Render framebuffer
  let panel = cast[ptr Panel](data)
  panel.width = int32(width)
  panel.height = int32(height)
  let img = drawPanelImg(panel)
  let buffer = panel.getBuffer(img)

  # Attach and Commit
  panel.surface.wl_surface_attach(buffer, 0, 0)
  panel.surface.wl_surface_commit()

const surfaceListener = zwlrLayerSurfaceV1Listener(
  configure: configureSurface,
  closed: surfaceClose
)

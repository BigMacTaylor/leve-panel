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
  ctx.fillStyle = p.color
  ctx.fill()

# ----------------------------------------------------------------------------------------
#                                    Update Widgets
# ----------------------------------------------------------------------------------------

proc updateWidget(w: ptr Widget) =
  let width = int32(w.endPos[0] - w.startPos[0])
  let height = int32(w.endPos[1] - w.startPos[1])

  # Copy new image to image data
  let panelStride = p.width
  var panelRowStart = w.startPos[1] * panelStride + w.startPos[0]
  var widgetRowStart = 0
  let rowBytes = width * 4

  for i in 0 ..< height:
    copyMem(
      p.pixelData[panelRowStart].addr,
      w.img.data[widgetRowStart].addr, 
      rowBytes
    )
    panelRowStart += panelStride
    widgetRowStart += width

  # Damage Surface
  p.surface.wl_surface_damage(int32(w.startPos[0]), int32(w.startPos[1]), width, height)

# ----------------------------------------------------------------------------------------
#                                    Create Widgets
# ----------------------------------------------------------------------------------------

proc createWidget(item: PanelItem, pos: float32, rdSide: Side): Widget =
  var widget: Widget

  case item.widget
  of WidgetType.favorite:
    widget = newFavWidget(item, pos, rdSide)
  of WidgetType.clock:
    widget = newClockWidget(item, pos, rdSide)
  of WidgetType.volume:
    widget = newVolWidget(item, pos, rdSide)
  of WidgetType.menu:
    widget = newMenuWidget(item, pos, rdSide)
  of WidgetType.power:
    widget = newPowerWidget(item, pos, rdSide)
  of WidgetType.desktop:
    widget = newDesktopWidget(item, pos, rdSide)
  of WidgetType.cpu:
    widget = newCpuWidget(item, pos, rdSide)
  of WidgetType.mem:
    widget = newMemWidget(item, pos, rdSide)

  return widget

# ----------------------------------------------------------------------------------------
#                                    Draw Panel
# ----------------------------------------------------------------------------------------

proc drawPanelImg(panel: ptr Panel): Image =
  echo "\nDrawing panel... \n"
  debug "pos: ", panel.pos
  debug "width: ", panel.width
  debug "height: ", panel.height

  let width = if panel.pos == top or panel.pos == bottom:
      panel.width
    else: panel.size

  let height = if panel.pos == top or panel.pos == bottom:
      panel.size
    else: panel.height

  # Create transparent image
  let img = newImage(width, height)
  let ctx = img.newContext()

  # Define panel dimensions and corner radius
  let xy = vec2(0, 0)
  let wh = vec2(float32(width), float32(height))
  let r = p.radius

  # Draw the panel background
  ctx.fillStyle = p.color
  ctx.fillRoundedRect(rect(xy, wh), r)

  # Zero out Widgets to avoid duplicates
  if widgets.len > 0:
    widgets = @[]

  # Add Left Widgets
  var endWidget = true
  var pos: float32 = 0
  var rdSide = none
  debug "get left items"
  let leftItems = panel.getItems("Left")
  for item in leftItems:
    if endWidget:
      if panel.pos == top or panel.pos == bottom:
        rdSide = left
      else:
        rdSide = top
    else: rdSide = none
    endWidget = false

    var widget: Widget = createWidget(item, pos, rdSide)

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
  debug "get center items"
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
    rdSide = none

    var widget: Widget = createWidget(item, pos, rdSide)

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
  debug "get right items"
  let rightItems = panel.getItems("Right")
  for item in rightItems:
    if item.widget == WidgetType.clock:
      pos = pos - float32(p.size)
    elif (item.widget == WidgetType.desktop) and (item.style != num):
      pos = pos - float32(3 * p.size)

    if endWidget:
      if panel.pos == top or panel.pos == bottom:
        rdSide = right
      else:
        rdSide = bottom
    else: rdSide = none
    endWidget = false

    var widget: Widget = createWidget(item, pos, rdSide)

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

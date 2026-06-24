# ========================================================================================
#
#                                   Leve Panel
#                                   Panel Bar
#
# ========================================================================================

proc wl_buffer_release(data: pointer, buffer: ptr wlBuffer) {.cdecl.} =
  # Sent by the compositor when it's no longer using this buffer
  echo "buffer release"
  #destroy(wl_buffer)

let wl_buffer_listener = wlBufferListener(release: wl_buffer_release)

# Shared memory support code
proc randname(buf: var openArray[char]) =
  var ts: Timespec
  discard clock_gettime(CLOCK_REALTIME, ts)
  var r = ts.tv_nsec
  for i in 0 ..< 6:
    buf[i] = char(ord('A') + (r and 15) + ((r and 16) shl 1))
    r = r shr 5

# Create a temporary shared memory file
proc create_shm_file(): cint =
  var retries = 100
  while retries > 0:
    var name_arr: array[15, char]
    for i, c in "/wl_shm-XXXXXX":
      name_arr[i] = c
    randname(name_arr.toOpenArray(8, 13))
    dec retries

    let fd =
      shm_open(cast[cstring](addr name_arr[0]), O_RDWR or O_CREAT or O_EXCL, 0o600)
    if fd >= 0:
      discard shm_unlink(cast[cstring](addr name_arr[0]))
      return fd

  return -1

proc allocate_shm_file(size: csize_t): cint =
  let fd = create_shm_file()
  if fd < 0:
    return -1

  var ret: cint
  while true:
    ret = ftruncate(fd, cint(size))
    if ret >= 0 or errno != EINTR:
      break

  if ret < 0:
    discard close(fd)
    return -1

  return fd

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

proc drawPanel(panel: ptr LevePanel): ptr wlBuffer =
  echo "\nDrawing panel... \n"
  if p.pixelData != nil:
    echo "data unmap"
    discard munmap(cast[pointer](p.pixelData), p.pixelDataSize)

  let width =
    if panel.pos == top or panel.pos == bottom:
      displayInfo.width
    else:
      panel.size
  let height =
    if panel.pos == top or panel.pos == bottom:
      panel.size
    else:
      displayInfo.height
  let stride = width * 4
  p.pixelDataSize = stride * height

  # Allocate Shared Memory (mmap)
  let fd = allocate_shm_file(csize_t(p.pixelDataSize))
  if fd == -1:
    return nil

  p.pixelData = cast[ptr UncheckedArray[uint32]](mmap(
    nil, p.pixelDataSize, PROT_READ or PROT_WRITE, MAP_SHARED, fd, 0
  ))
  if cast[int](p.pixelData) == cast[int](MAP_FAILED):
    discard close(fd)
    return nil

  let memPool = panel.shMem.wl_shm_create_pool(int32(fd), p.pixelDataSize)

  if panel.buffer != nil:
    echo "buffer destroy"
    wl_buffer_destroy(panel.buffer)

  panel.buffer = memPool.wl_shm_pool_create_buffer(
    #0, cint(width), cint(height), cint(stride), cast[uint32](format_xrgb8888)
    int32(0),
    int32(width),
    int32(height),
    int32(stride),
    uint32(ShmFormat.XBGR8888),
  )

  # Create panel bar area
  let panelBG = newImage(width, height)
  panelBG.fill(parseHtmlColor(p.color))

  let ctx = panelBG.newContext()

  # Zero out Widgets to avoid duplicates
  if widgets.len > 0:
    widgets = @[]

  # Add Left Widgets
  var pos: float32 = 0
  for item in leftItems:
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

  # Get pos for Center Items
  var centerItemsSize = 0
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
  for item in rightItems:
    if item.widget == WidgetType.clock:
      pos = pos - float32(p.size)
    elif (item.widget == WidgetType.desktop) and (item.style != num):
      pos = pos - float32(3 * p.size)

    var widget: Widget = createWidget(item, pos)

    widgets.add(widget)

    if p.pos == top or p.pos == bottom:
      ctx.drawImage(widget.img, pos, 0)
    else:
      ctx.drawImage(widget.img, 0, pos)

    pos = pos - float32(p.size)

  # Copy to shared buffer
  # Pixie stores data as a seq[ColorRGBX], which is 4 bytes per pixel
  copyMem(p.pixelData, panelBG.data[0].addr, p.pixelDataSize)

  # Cleanup
  wl_shm_pool_destroy(memPool)
  discard close(fd)
  #discard munmap(cast[pointer](p.pixelData), p.pixelDataSize)

  discard panel.buffer.wl_buffer_add_listener(addr wl_buffer_listener, nil)
  return cast[ptr wl_buffer](panel.buffer)

# ----------------------------------------------------------------------------------------
#                                    Update Widgets
# ----------------------------------------------------------------------------------------

proc updateWidget(w: ptr Widget) =
  let width = int32(w.endPos[0] - w.startPos[0])
  let height = int32(w.endPos[1] - w.startPos[1])

  # Draw damaged area
  let newImgData = newImage(width, height)
  newImgData.fill(parseHtmlColor(p.color))
  let ctx = newImgData.newContext()
  ctx.drawImage(w.img, 0, 0)

  # Copy new area to image data
  var dataPos = 0
  var newDataPos = 0

  if p.pos == top or p.pos == bottom:
    dataPos = w.startPos[0]
    for i in 0 ..< height:
      copyMem(p.pixelData[dataPos].addr, newImgData.data[newDataPos].addr, width * 4)
      dataPos = dataPos + displayInfo.width
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
#                                    Configure Surface
# ----------------------------------------------------------------------------------------

proc surfaceClose(
    data: pointer,
    surface: ptr zwlr_layer_surface_v1,
) {.cdecl.} =

  echo "Layer surface closed by compositor"
    
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

  cast[ptr zwlr_layer_surface_v1](surface).zwlr_layer_surface_v1_ack_configure(serial)

  echo "[Surface] Configure event"

  if displayInfo.changed == false:
    return

  displayInfo.changed = false

  if p.buffer != nil:
    echo "Redraw panel"

  let panel = cast[ptr LevePanel](data)
  let buffer = drawPanel(panel)

  # Attach and Commit
  panel.surface.wl_surface_attach(buffer, int32(0), int32(0))
  panel.surface.wl_surface_commit()

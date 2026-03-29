# ========================================================================================
#
#                                   Leve Panel
#                                   Panel Bar
#
# ========================================================================================

proc wl_buffer_release(data: pointer, buffer: ptr wlBuffer) {.cdecl.} =
  # Sent by the compositor when it's no longer using this buffer
  #destroy(wl_buffer)
  echo "fix me"

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
#                                    Draw Panel
# ----------------------------------------------------------------------------------------

proc drawFrame(panel: ptr LevePanel): ptr wlBuffer =
  echo "Drawing frame"
  let width = displayInfo.width
  let height = panel.size
  let stride = width * 4
  let size = stride * height

  # Allocate Shared Memory (mmap)
  let fd = allocate_shm_file(csize_t(size))
  if fd == -1:
    return nil

  p.pixelData = cast[ptr UncheckedArray[uint32]](mmap(
    nil, size, PROT_READ or PROT_WRITE, MAP_SHARED, fd, 0
  ))
  if cast[int](p.pixelData) == cast[int](MAP_FAILED):
    discard close(fd)
    return nil

  let memPool = panel.shMem.wl_shm_create_pool(int32(fd), size)
  panel.buffer = memPool.wl_shm_pool_create_buffer(
  #let buffer = get pool.createBuffer(
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

  # Add favorite buttons
  var pos: float32 = 0
  for item in leftItems:
    var widget: Widget
    case item.widget
    of WidgetType.favorite:
      # newWidget = (item, startPos, endPos)
      widget = newFavWidget(item, [int(pos), 0], [int(pos) + p.size, p.size])
    of WidgetType.clock:
      widget = newClockWidget(item, [int(pos), 0], [int(pos) + (2 * p.size), p.size])
    of WidgetType.volume:
      widget = newVolWidget(item, [int(pos), 0], [int(pos) + p.size, p.size])
    of WidgetType.power:
      widget = newPowerWidget(item, [int(pos), 0], [int(pos) + p.size, p.size])

    widgets.add(widget)
    ctx.drawImage(widget.img, pos, 0)
    if item.widget == WidgetType.clock:
      pos = pos + float32(p.size)
    pos = pos + float32(p.size)

  # Placeholder for switcher
  pos = (width / 2) - float32(p.size)
  #let clock = newClockWidget([int(pos), 0], [int(pos) + (2 * p.size), p.size])
  #widgets.add(clock)
  #ctx.drawImage(clock.img, pos, 0)

  # Add system tray widgets
  pos = float32(width - p.size)
  for item in rightItems:
    var widget: Widget
    case item.widget
    of WidgetType.favorite:
      widget = newFavWidget(item, [int(pos), 0], [int(pos) + p.size, p.size])
    of WidgetType.clock:
      pos = pos - float32(p.size)
      widget = newClockWidget(item, [int(pos), 0], [int(pos) + (2 * p.size), p.size])
    of WidgetType.volume:
      widget = newVolWidget(item, [int(pos), 0], [int(pos) + p.size, p.size])
    of WidgetType.power:
      widget = newPowerWidget(item, [int(pos), 0], [int(pos) + p.size, p.size])

    widgets.add(widget)
    ctx.drawImage(widget.img, pos, 0)
    pos = pos - float32(p.size)

  # Copy to shared buffer
  # Pixie stores data as a seq[ColorRGBX], which is 4 bytes per pixel
  copyMem(p.pixelData, panelBG.data[0].addr, size)

  # Cleanup
  #destroy(memPool)
  discard close(fd)
  #discard munmap(cast[pointer](p.pixelData), size)

  discard panel.buffer.wl_buffer_add_listener(addr wl_buffer_listener, nil)
  return cast[ptr wl_buffer](panel.buffer)

# ----------------------------------------------------------------------------------------
#                                    Update Widgets
# ----------------------------------------------------------------------------------------

proc updateWidget(w: ptr Widget) =
  let width = int32(w.endPos[0] - w.startPos[0])
  let height = p.size

  # Draw damaged area
  let newImgData = newImage(width, height)
  newImgData.fill(parseHtmlColor(p.color))
  let ctx = newImgData.newContext()
  ctx.drawImage(w.img, 0, 0)

  # Copy new area to image data
  var dataPos = w.startPos[0]
  var newDataPos = 0

  for i in 0 ..< height:
    copyMem(p.pixelData[dataPos].addr, newImgData.data[newDataPos].addr, width * 4)
    dataPos = dataPos + displayInfo.width
    newDataPos = newDataPos + width

  # Attach and Damage
  p.surface.wl_surface_attach(p.buffer, 0, 0)
  p.surface.wl_surface_damage(int32(w.startPos[0]), 0, width, height)

# ----------------------------------------------------------------------------------------
#                                    Configure Surface
# ----------------------------------------------------------------------------------------

proc configureSurface(
    data: pointer,
    surface: ptr zwlr_layer_surface_v1,
    serial: uint32,
    width: uint32,
    height: uint32,
) {.cdecl.} =

  if p.buffer != nil:
    #destroy(p.buffer)
    return

  let panel = cast[ptr LevePanel](data)
  cast[ptr zwlr_layer_surface_v1](surface).zwlr_layer_surface_v1_ack_configure(serial)

  let buffer = drawFrame(panel)

  # Attach and Commit
  panel.surface.wl_surface_attach(buffer, int32(0), int32(0))
  panel.surface.wl_surface_commit()

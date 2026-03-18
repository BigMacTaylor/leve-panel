# ========================================================================================
#
#                                   Leve Panel
#                                   Panel Bar
#
# ========================================================================================

proc wl_buffer_release(data: pointer, wl_buffer: ptr wl.Buffer) =
  # Sent by the compositor when it's no longer using this buffer
  destroy(wl_buffer)

let wl_buffer_listener = wl.BufferListener(release: wl_buffer_release)

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


proc exec(fav: ptr Favorite) =
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
  echo cast[ptr Favorite](fav).name
  exec(cast[ptr Favorite](fav))
  #echo new.name


# ----------------------------------------------------------------------------------------
#                                    Draw Panel
# ----------------------------------------------------------------------------------------

proc drawFrame(panel: ptr LevePanel): ptr wl.Buffer =
  echo "Drawing frame"
  let width = display.width
  let height = panel.size
  let stride = width * 4
  let size = stride * height

  # Allocate Shared Memory (mmap)
  let fd = allocate_shm_file(csize_t(size))
  if fd == -1:
    return nil

  let pixelData = cast[ptr UncheckedArray[uint32]](mmap(
    nil, size, PROT_READ or PROT_WRITE, MAP_SHARED, fd, 0
  ))
  if cast[int](pixelData) == cast[int](MAP_FAILED):
    discard close(fd)
    return nil

  let pool = panel.memBuffer.create_pool(fd, cint(size))
  let buffer = pool.create_buffer(
    #0, cint(width), cint(height), cint(stride), cast[uint32](format_xrgb8888)
    0, cint(width), cint(height), cint(stride), cast[uint32](format_xbgr8888)
  )

  # Create panel bar area
  let panelBG = newImage(width, height)
  panelBG.fill(parseHtmlColor(p.color))

  let ctx = panelBG.newContext()

  # Add favorite buttons
  var id = 0
  var pos: float32 = 0

  # Zero out hitBoxes to avoid duplicates
  if hitBoxes.len > 0:
    hitBoxes = @[]

  for fav in favorites:
    let hitBox: HitBox = (id: id, start: [int(pos), 0], `end`: [int(pos) + panel.size, 0 + panel.size], handler: onFavClick, data: addr fav)
    hitBoxes.add(hitBox)
    let favBtn = createBtn(fav)
    ctx.drawImage(favBtn, pos, 0)
    pos = pos + float32(panel.size)
    id = id + 1

  # Placeholder for switcher
  pos = (width / 2) - float32(p.size)
  let widget = newClockWidget()
  ctx.drawImage(widget, pos, 0)


  # Add system tray items
  pos = float32(width - p.size)
  pos = pos - float32(p.size)

  let clock = newClockWidget()
  ctx.drawImage(clock, pos, 0)
  pos = pos - float32(p.size)

  let vol = newVolWidget()
  ctx.drawImage(vol, pos, 0)
  pos = pos - float32(p.size)


  # Copy to shared buffer
  # Pixie stores data as a seq[ColorRGBX], which is 4 bytes per pixel
  copyMem(pixelData, panelBG.data[0].addr, size)

  # Cleanup
  destroy(pool)
  discard close(fd)
  discard munmap(cast[pointer](pixelData), size)

  discard buffer.add_listener(addr wl_buffer_listener, nil)
  return buffer

# ----------------------------------------------------------------------------------------
#                                    Configure Surface
# ----------------------------------------------------------------------------------------

proc configureSurface(
    data: pointer,
    surface: ptr ZwlrLayerSurfaceV1,
    serial: uint32,
    width: uint32,
    height: uint32,
) =
  let panel = cast[ptr LevePanel](data)
  surface.ackConfigure(serial)

  let buffer = drawFrame(panel)

  # Attach and Commit
  panel.surface.attach(buffer, 0, 0)
  panel.surface.commit()

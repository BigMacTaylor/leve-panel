# ========================================================================================
#
#                                   Leve Panel
#                                   Wl Buffer
#
# ========================================================================================

proc wl_buffer_release(data: pointer, buffer: ptr wlBuffer) {.cdecl.} =
  # Sent by the compositor when it's no longer using this buffer
  debug "buffer release"
  #wl_buffer_destroy(buffer)

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
proc createShmFd(): cint =
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

proc createShmFile(size: int32): cint =
  let fd = createShmFd()
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
#                                    Get Buffer
# ----------------------------------------------------------------------------------------

proc getBuffer(data: pointer, img: Image): ptr wlBuffer =
  let surface = cast[ptr Surface](data)

  if surface.pixelData != nil:
    echo "data unmap"
    discard munmap(surface.pixelData, surface.pixelDataSize)

  let width = int32(img.width)
  let height = int32(img.height)
  let stride = width * 4

  surface.pixelDataSize = stride * height

  # Allocate Shared Memory (mmap)
  let fd = createShmFile(surface.pixelDataSize)
  if fd == -1:
    return nil

  surface.pixelData = cast[ptr UncheckedArray[uint32]](mmap(
    nil, surface.pixelDataSize, PROT_READ or PROT_WRITE, MAP_SHARED, fd, 0
  ))

  if surface.pixelData == MAP_FAILED:
    echo "mmap failed"
    discard close(fd)
    return nil

  let memPool = s.shMem.wl_shm_create_pool(int32(fd), surface.pixelDataSize)

  if surface.buffer != nil:
    echo "buffer destroy"
    wl_buffer_destroy(surface.buffer)

  surface.buffer = memPool.wl_shm_pool_create_buffer(
    int32(0),
    int32(width),
    int32(height),
    int32(stride),
    uint32(ShmFormat.ABGR8888),
  )

  # Copy to shared buffer
  # Pixie stores data as a seq[ColorRGBX], which is 4 bytes per pixel
  copyMem(surface.pixelData, img.data[0].addr, surface.pixelDataSize)

  # Cleanup
  wl_shm_pool_destroy(memPool)
  discard close(fd)
  #discard munmap(s.pixelData, s.pixelDataSize)

  discard surface.buffer.wl_buffer_add_listener(addr wl_buffer_listener, nil)

  return surface.buffer


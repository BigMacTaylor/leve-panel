# ========================================================================================
#
#                                   Leve Panel
#                                    Tooltip
#
# ========================================================================================

type Popup = ref object
  pos_x: int32
  pos_y: int32
  width: int32
  height: int32
  pixelData: ptr UncheckedArray[uint32]
  pixelDataSize: int32
  shMem: ptr wl_shm
  buffer: ptr wl_buffer
  surface: ptr wl_surface
  xdgSurface: ptr xdg_surface
  xdgPopup: ptr xdg_shell.xdg_popup
  parent: ptr zwlrLayerSurfaceV1
  widgetNum: int

type Tooltip = ref object
  text: string
  popup: Popup

type Menu = ref object
  text: string
  popup: Popup

let pUp = Popup()
var tt = Tooltip()
var m = Menu()
tt.popup = pUp
m.popup = pUp


proc popupConfigure(
    data: pointer,
    popup: ptr xdg_shell.xdg_popup,
    x, y, width, height: int32
) {.cdecl.} =
  echo "Popup configured to size: ", width, "x", height, " at offset (", x, ", ", y, ")"

  let popupData = cast[ptr Popup](data)
  popupData.pos_x = x
  popupData.pos_y = y
  popupData.width = width
  popupData.height = height

proc destroyPopup(popup: Popup) =
  echo "Destroy popup"
  if popup.xdgPopup != nil:
    popup.xdgPopup.xdg_popup_destroy()
    popup.xdgPopup = nil
  if popup.xdgSurface != nil:
    popup.xdgSurface.xdg_surface_destroy()
    popup.xdgSurface = nil
  if popup.surface != nil:
    popup.surface.wl_surface_destroy()
    popup.surface = nil
  if popup.buffer != nil:
    popup.buffer.wl_buffer_destroy()
    popup.buffer = nil

  echo "Popup destroyed"

proc popupClose(data: pointer; popup: ptr xdg_shell.xdg_popup) {.cdecl.} =
  # Handle when the compositor requests the popup to close (e.g., click away)
  echo "Popup dismissed"
  #popup.xdg_popup_destroy()
  pUp.destroyPopup()

let popupListener = xdg_popup_listener(
    configure: popupConfigure,
    popup_done: popupClose
)

proc drawPopup(popup: ptr Popup): ptr wlBuffer =
  echo "\nDrawing popup... "
  echo "Size: ", popup.width, "x", popup.height, " at offset (", popup.pos_x, ", ", popup.pos_y, ")"

  if pUp.pixelData != nil:
    echo "data unmap"
    discard munmap(cast[pointer](pUp.pixelData), pUp.pixelDataSize)

  let width = popup.width
  let height = popup.height

  let stride = width * 4
  pUp.pixelDataSize = stride * height

  # Allocate Shared Memory (mmap)
  let fd = allocate_shm_file(csize_t(pUp.pixelDataSize))
  if fd == -1:
    return nil

  pUp.pixelData = cast[ptr UncheckedArray[uint32]](mmap(
    nil, pUp.pixelDataSize, PROT_READ or PROT_WRITE, MAP_SHARED, fd, 0
  ))

  if cast[int](pUp.pixelData) == cast[int](MAP_FAILED):
    discard close(fd)
    return nil

  let memPool = p.shMem.wl_shm_create_pool(int32(fd), pUp.pixelDataSize)

  #if popup.buffer != nil:
  #  echo "buffer destroy"
  #  wl_buffer_destroy(popup.buffer)

  let buffer = memPool.wl_shm_pool_create_buffer(
    int32(0),
    int32(width),
    int32(height),
    int32(stride),
    uint32(ShmFormat.XBGR8888),
  )

  let text = tt.text
  var img = newImage(width, height)
  let ctx = img.newContext()

  img.fill(rgba(40, 40, 40, 255)) # Dark gray background
  #tooltipImage.fill(parseHtmlColor(p.color))

  # Draw Text
  let font = try:
    readFont(fontPath)
  except:
    fontPath = getFont()
    readFont(fontPath)

  font.size = 14
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

  # Copy to shared buffer
  # Pixie stores data as a seq[ColorRGBX], which is 4 bytes per pixel
  copyMem(pUp.pixelData, img.data[0].addr, pUp.pixelDataSize)

  # Cleanup
  wl_shm_pool_destroy(memPool)
  discard close(fd)

  return cast[ptr wl_buffer](buffer)

proc handleXdgSurfaceConfigure(
    data: pointer, 
    xdgSurface: ptr xdg_surface, 
    serial: uint32
) {.cdecl.} =
  echo "[Xdg Surface] Configure event"

  xdgSurface.xdg_surface_ack_configure(serial)

  if pUp.buffer != nil:
    echo "buffer not empty"
    return

  # Update the window geometry using the dimensions provided by the compositor
  # This is crucial for Wayland popups to align correctly with their parents
  #xdgSurface.xdg_surface_set_window_geometry(tt.popup.pos_x, tt.popup.pos_y, tt.popup.width, tt.popup.height)
  #  xdgSurface.xdg_surface_set_window_geometry(0, 0, popup.width, popup.height)

  # Render framebuffer
  let popupData = cast[ptr Popup](data)
  let buffer = drawPopup(popupData)

  # Attach and Commit
  popupData.surface.wl_surface_attach(buffer, int32(0), int32(0))
  popupData.surface.wl_surface_commit()

let xdgSurfaceListener = xdgSurfaceListener(
  configure: handleXdgSurfaceConfigure
)

proc createPopup[T](x, y, width, height: int32, data: ptr T) =
  echo "create popup"

  # 1. Create a wl surface for the tooltip
  data.popup.surface = p.compositor.wl_compositor_create_surface()

  # 2. Get the xdg_surface wrapper
  data.popup.xdgSurface = p.xdgWmBase.xdg_wm_base_get_xdg_surface(data.popup.surface)

  # Define where the tooltip should appear relative to parent surface
  let positioner = p.xdgWmBase.xdg_wm_base_create_positioner()
  positioner.xdg_positioner_set_size(data.popup.width, data.popup.height)
  positioner.xdg_positioner_set_anchor_rect(x, y, width, height)
  #positioner.xdg_positioner_set_offset(0, 5)
  positioner.xdg_positioner_set_anchor(XDG_POSITIONER_ANCHOR_TOP.uint32) 
  positioner.xdg_positioner_set_gravity(XDG_POSITIONER_GRAVITY_TOP.uint32)
  positioner.xdg_positioner_set_constraint_adjustment(15)

  # 4. Assign the Popup role
  # Extract the xdg_popup role from the XdgSurface (null parent goes here initially)
  data.popup.xdgPopup = data.popup.xdgSurface.xdg_surface_get_popup(nil, positioner)

  #discard wl_display_roundtrip(p.display)

  # Tell the layer shell that this popup belongs directly to your layer_surface
  p.layerSurface.zwlr_layer_surface_v1_get_popup(cast[ptr wlr_layer_shell_unstable_v1.xdg_popup](data.popup.xdgPopup))

  # Grab seat
  data.popup.xdgPopup.xdg_popup_grab(p.seat, pointerState.serial)

  # Listen for configure events
  discard data.popup.xdgSurface.xdg_surface_add_listener(addr xdgSurfaceListener, addr data.popup)
  discard data.popup.xdgPopup.xdg_popup_add_listener(addr popupListener, addr data.popup)

  # 6. Attach buffer/content to the tooltip surface & commit
  #tt.popup.surface.wl_surface_attach(tt.popup.buffer, int32(0), int32(0))

  # 7. Commit the base tooltip surface state to trigger the compositor configuration
  data.popup.surface.wl_surface_commit()
  
  # Clean up the positioner object as it is no longer required after getPopup
  positioner.xdg_positioner_destroy()

proc createTooltip(w: Widget) =
  echo "create tooltip"

  case w.widgetType
  of WidgetType.clock:
    tt.text = getDate()
  of WidgetType.volume:
    if volMute:
      tt.text = "Volume: Muted"
    else:
      tt.text = "Volume: " & $cur_vol & "%"
  else:
    return

  tt.popup.width = 110
  tt.popup.height = 30

  createPopup(
    int32(w.startPos[0]),
    int32(w.startPos[1]),
    int32(w.endPos[0] - w.startPos[0]),
    int32(w.endPos[1] - w.startPos[1]),
    addr tt
  )

proc onPing(data: pointer, xdg_wm_base: ptr xdg_wm_base, serial: uint32) {.cdecl.} =
  echo "Pong"

let xdgBaseListener = xdg_wm_base_listener(
  ping: onPing
)

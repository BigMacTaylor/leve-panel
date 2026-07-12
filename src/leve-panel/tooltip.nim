# ========================================================================================
#
#                                   Leve Panel
#                                    Tooltip
#
# ========================================================================================

proc popupConfigure(
  data: pointer,
  popup: ptr xdg_shell.xdg_popup,
  x, y, width, height: int32
) {.cdecl.} =
  echo "Popup configured to size: ", width, "x", height, " at offset (", x, ", ", y, ")"

  let popupData = cast[ptr PopupSurface](data)
  popupData.pos_x = x
  popupData.pos_y = y
  popupData.width = width
  popupData.height = height

proc destroyPopup(data: pointer) =
  let popup = cast[ptr PopupSurface](data)

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

proc popupClose(data: pointer, popup: ptr xdg_shell.xdg_popup) {.cdecl.} =
  # Handle when the compositor requests the popup to close (e.g., click away)
  echo "Popup dismissed"
  let popup = cast[ptr PopupSurface](data)
  #popup.xdg_popup_destroy()
  popup.destroyPopup()

let popupListener = xdg_popup_listener(
  configure: popupConfigure,
  popup_done: popupClose
)

proc newMenuImg(menu: ptr Menu): Image =
  echo "\nDrawing menu... "

  let width = menu.width
  let height = menu.height

  # Draw tooltip background
  var img = newImage(width, height)
  img.fill(rgba(40, 40, 40, 255)) # Dark gray

  # Draw text
  let text = menu.text
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

  return img

proc newTooltipImg(tooltip: ptr Tooltip): Image =
  echo "\nDrawing tooltip... "

  let width = tooltip.width
  let height = tooltip.height

  # Draw tooltip background
  var img = newImage(width, height)
  img.fill(rgba(40, 40, 40, 255)) # Dark gray

  # Draw text
  let text = tooltip.text
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

  return img

proc updateTooltip(tooltip: ptr Tooltip) =
  let width = tooltip.width
  let height = tooltip.height

  # Draw tooltip
  let img = newTooltipImg(tooltip)

  # Copy new image to shared buffer
  copyMem(tooltip.pixelData, img.data[0].addr, tooltip.pixelDataSize)

  # Attach and Damage
  tooltip.surface.wl_surface_attach(tooltip.buffer, 0, 0)
  tooltip.surface.wl_surface_damage(0, 0, width, height)

proc handleXdgSurfaceConfigure(
  data: pointer, 
  xdgSurface: ptr xdg_surface, 
  serial: uint32
) {.cdecl.} =
  echo "[Xdg Surface] Configure event"

  xdgSurface.xdg_surface_ack_configure(serial)

  # Render framebuffer
  let popup = cast[ptr PopupSurface](data)
  let img = if popup of Tooltip:
    newTooltipImg(cast[ptr Tooltip](data))
  else:
    newMenuImg(cast[ptr Menu](data))
  let buffer = popup.getBuffer(img)

  # Attach and Commit
  popup.surface.wl_surface_attach(buffer, 0, 0)
  popup.surface.wl_surface_commit()

let xdgSurfaceListener = xdgSurfaceListener(
  configure: handleXdgSurfaceConfigure
)

proc createPopup(x, y, width, height: int32, data: pointer) =
  let popup = cast[ptr PopupSurface](data)

  # Create a wl surface for the tooltip
  popup.surface = s.compositor.wl_compositor_create_surface()

  # Get the xdg_surface wrapper
  popup.xdgSurface = s.xdgWmBase.xdg_wm_base_get_xdg_surface(popup.surface)

  # Define where the tooltip should appear relative to parent surface
  let positioner = s.xdgWmBase.xdg_wm_base_create_positioner()
  positioner.xdg_positioner_set_size(popup.width, popup.height)
  positioner.xdg_positioner_set_anchor_rect(x, y, width, height)
  #positioner.xdg_positioner_set_offset(0, 5)
  positioner.xdg_positioner_set_anchor(XDG_POSITIONER_ANCHOR_TOP.uint32) 
  positioner.xdg_positioner_set_gravity(XDG_POSITIONER_GRAVITY_TOP.uint32)
  positioner.xdg_positioner_set_constraint_adjustment(15)

  # Assign the Popup role
  popup.xdgPopup = popup.xdgSurface.xdg_surface_get_popup(nil, positioner)

  #discard wl_display_roundtrip(s.display)

  # Tell the layer shell that this popup belongs directly to the layer_surface
  s.layerSurface.zwlr_layer_surface_v1_get_popup(cast[ptr wlr_layer_shell_unstable_v1.xdg_popup](popup.xdgPopup))

  # Grab seat
  popup.xdgPopup.xdg_popup_grab(s.seat, pointerState.serial)

  # Listen for configure events
  discard popup.xdgSurface.xdg_surface_add_listener(addr xdgSurfaceListener, data)
  discard popup.xdgPopup.xdg_popup_add_listener(addr popupListener, data)

  # Commit the surface to trigger the configure event
  popup.surface.wl_surface_commit()

  # Clean up
  positioner.xdg_positioner_destroy()

proc createTooltip(w: Widget) =
  echo "create tooltip"
  tt.height = 30

  case w.widgetType
  of WidgetType.clock:
    tt.width = 150
    tt.text = getDate()
  of WidgetType.volume:
    tt.width = 100
    if volMute:
      tt.text = "Volume: Muted"
    else:
      tt.text = "Volume: " & $cur_vol & "%"
  else:
    return

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

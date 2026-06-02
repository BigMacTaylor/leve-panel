# ========================================================================================
#
#                                   Leve Panel
#                                   Callbacks
#
# ========================================================================================

proc seatCapabilities(data: pointer, seat: ptr  wl_seat, capabilities: uint32) {.cdecl.} =
  discard

proc fixedToDouble(f: wl_fixed): float =
  return float(f / 256)

# Pointer Motion
proc pointerHandleMotion(
    data: pointer, pointer: ptr wl_pointer, time: uint32, surfaceX: wl_fixed, surfaceY: wl_fixed
) {.cdecl.} =
  # Convert Wayland fixed point to float/integer
  p.mouse_x = fixedToDouble(surfaceX)
  p.mouse_y = fixedToDouble(surfaceY)
  echo "Mouse Moved: ", p.mouse_x, ", ", p.mouse_y

proc isWithin(w: Widget, x, y: int): bool =
  #if x >= w.startPos[0] and x <= w.endPos[0] and y >= w.startPos[1] and y <= w.endPos[1]:
  if x >= w.startPos[0] and x <= w.endPos[0]:
    echo "Within bounds !"
    return true

# Button Click
proc pointerHandleButton(
    data: pointer,
    pointer: ptr wl_pointer,
    serial: uint32,
    time: uint32,
    button: uint32,
    state: uint32,
) {.cdecl.} =

  if state == 1:
    echo "Button clicked: ", button, " ", p.mouse_x, ", ", p.mouse_y

  if state == 1 and button == 272:
    for widget in widgets:
      if widget.isWithin(int(p.mouse_x), int(p.mouse_y)):
        for cb in widget.callBacks:
          if cb.event == "click_l":
            echo "clicked"
            cb.handler(addr widget)
            return # Found it, stop looking

  if state == 1 and button == 273:
    for widget in widgets:
      if widget.isWithin(int(p.mouse_x), int(p.mouse_y)):
        for cb in widget.callBacks:
          if cb.event == "click_r":
            echo "clicked"
            cb.handler(addr widget)
            return # Found it, stop looking

  if state == 1 and button == 274:
    for widget in widgets:
      if widget.isWithin(int(p.mouse_x), int(p.mouse_y)):
        for cb in widget.callBacks:
          if cb.event == "click_m":
            echo "clicked"
            cb.handler(addr widget)
            return # Found it, stop looking


# Enter Surface
proc pointerHandleEnter(
    data: pointer,
    pointer: ptr wl_pointer,
    serial: uint32,
    surface: ptr wlSurface,
    surfaceX: wl_fixed,
    surfaceY: wl_fixed,
) {.cdecl.} =
  echo "Pointer entered surface"

# Leave Surface
proc pointerHandleLeave(
    data: pointer, pointer: ptr wl_pointer, serial: uint32, surface: ptr wl_surface
) {.cdecl.} =
  #p.pointer.event = Event.leave
  echo "Pointer left surface"

var lastScrollTime = getMonoTime()

# Scroll on Surface
proc pointerHandleScroll(
    data: pointer, pointer: ptr wl_pointer, time: uint32, axis: uint32, value: wl_fixed
) {.cdecl.} =
  echo "Pointer scroll on surface"
  echo axis
  echo value

  let now = getMonoTime()

  # Debounce scroll event
  if now < lastScrollTime + initDuration(milliseconds = 60):
    if now < lastScrollTime + initDuration(milliseconds = 10):
      lastScrollTime = now
    return

  if axis == 0 and value == -3840: # scroll up
    for widget in widgets:
      if widget.isWithin(int(p.mouse_x), int(p.mouse_y)):
        for cb in widget.callBacks:
          if cb.event == "scroll_up":
            echo "scroll_up"
            cb.handler(addr widget)
            return # Found it, stop looking
    discard execShellCmd(p.scrollUpCmd)

  if axis == 0 and value == 3840: # scroll down
    for widget in widgets:
      if widget.isWithin(int(p.mouse_x), int(p.mouse_y)):
        for cb in widget.callBacks:
          if cb.event == "scroll_down":
            echo "scroll_down"
            cb.handler(addr widget)
            return # Found it, stop looking
    discard execShellCmd(p.scrollDownCmd)

  lastScrollTime = now

# Setup Pointer Listener
var pointerListener = wlPointerListener(
  enter: pointerHandleEnter,
  leave: pointerHandleLeave, # Handle leave if needed
  motion: pointerHandleMotion,
  button: pointerHandleButton,
  axis: pointerHandleScroll, # Handle scroll if needed
  frame: nil,
  axis_source: nil,
  axis_stop: nil,
  axis_discrete: nil,
)

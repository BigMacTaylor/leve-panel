# ========================================================================================
#
#                                   Leve Panel
#                                   Callbacks
#
# ========================================================================================

func fixedToDouble(f: wl_fixed): float =
  return float(f / 256)

func isWithin(w: Widget, x, y: int): bool =
  if x >= w.startPos[0] and x <= w.endPos[0] and y >= w.startPos[1] and y <= w.endPos[1]:
    return true

# Pointer Motion
proc pointerHandleMotion(
    data: pointer, pointer: ptr wl_pointer, time: uint32, surfaceX: wl_fixed, surfaceY: wl_fixed
) {.cdecl.} =
  # Convert Wayland fixed point to float/integer
  pointerState.x = fixedToDouble(surfaceX)
  pointerState.y = fixedToDouble(surfaceY)
  pointerState.motionPending = true

# Button Click
proc pointerHandleButton(
    data: pointer,
    pointer: ptr wl_pointer,
    serial: uint32,
    time: uint32,
    button: uint32,
    state: uint32,
) {.cdecl.} =

  pointerState.button = button
  pointerState.btnPressed = (state != 0)
  pointerState.serial = serial
  pointerState.buttonPending = true

  if state == 1 and button == 272:
    for widget in widgets:
      if widget.isWithin(int(pointerState.x), int(pointerState.y)):
        for cb in widget.callBacks:
          if cb.event == Event.click_l:
            echo "clicked"
            cb.handler(addr widget)
            return # Found it, stop looking

  if state == 1 and button == 273:
    for widget in widgets:
      if widget.isWithin(int(pointerState.x), int(pointerState.y)):
        for cb in widget.callBacks:
          if cb.event == Event.click_r:
            echo "clicked"
            cb.handler(addr widget)
            return # Found it, stop looking

  if state == 1 and button == 274:
    for widget in widgets:
      if widget.isWithin(int(pointerState.x), int(pointerState.y)):
        for cb in widget.callBacks:
          if cb.event == Event.click_m:
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
  echo "[Pointer] Entered surface"

  if p.cursor.isNil:
    echo "Setting cursor shape"
    p.cursor = p.cursor_manager.wp_cursor_shape_manager_v1_get_pointer(pointer)

  p.cursor.wp_cursor_shape_device_v1_set_shape(serial, wp_cursor_shape_device_v1_shape.WP_CURSOR_SHAPE_DEVICE_V1_SHAPE_DEFAULT.ord)

# Leave Surface
proc pointerHandleLeave(
    data: pointer, pointer: ptr wl_pointer, serial: uint32, surface: ptr wl_surface
) {.cdecl.} =
  #p.pointer.event = Event.leave
  echo "[Pointer] Left surface"

  pUp.destroyPopup()
  pUp.widgetNum = 0

var lastScrollTime = getMonoTime()

# Scroll on Surface
proc pointerHandleScroll(
    data: pointer, pointer: ptr wl_pointer, time: uint32, axis: uint32, value: wl_fixed
) {.cdecl.} =
  echo "[Pointer] Scroll on surface"
  echo axis
  echo value

  let now = getMonoTime()

  # Debounce scroll event
  if now < lastScrollTime + initDuration(milliseconds = 60): # 60
    if now < lastScrollTime + initDuration(milliseconds = 10): # 10
      lastScrollTime = now
    return

  if axis == 0 and value == -3840: # scroll up
    for widget in widgets:
      if widget.isWithin(int(pointerState.x), int(pointerState.y)):
        for cb in widget.callBacks:
          if cb.event == Event.scroll_up:
            echo "scroll_up"
            cb.handler(addr widget)
            return # Found it, stop looking
    discard execShellCmd(p.scrollUpCmd)

  if axis == 0 and value == 3840: # scroll down
    for widget in widgets:
      if widget.isWithin(int(pointerState.x), int(pointerState.y)):
        for cb in widget.callBacks:
          if cb.event == Event.scroll_down:
            echo "scroll_down"
            cb.handler(addr widget)
            return # Found it, stop looking
    discard execShellCmd(p.scrollDownCmd)

  lastScrollTime = now

var lastPopupTime = getMonoTime()

proc pointerHandleFrame(data: pointer, pointer: ptr wl_pointer) {.cdecl.} =
  # Process pointer frame data
  if pointerState.motionPending:
    echo "[Pointer] Mouse moved: ", pointerState.x, " ", pointerState.y
    pointerState.motionPending = false

    var newNum = 0

    for i in 0 ..< widgets.len:
      if widgets[i].isWithin(int(pointerState.x), int(pointerState.y)):
        echo "[Pointer] Hovering ", widgets[i].widgetType
        newNum = i + 1
        break
      else:
        newNum = 0

    if newNum == pUp.widgetNum:
      discard
    elif newNum == 0:
      pUp.destroyPopup()
      pUp.widgetNum = 0
    else:
      pUp.destroyPopup()
      pUp.widgetNum = newNum
      let now = getMonoTime()
      if now > lastPopupTime + initDuration(milliseconds = 1500):
        sleep(600)
      lastPopupTime = now
      widgets[newNum - 1].createTooltip()

  if pointerState.buttonPending:
    echo "[Pointer] Button \'", pointerState.button, "\' pressed: ", pointerState.btnPressed, " ", pointerState.x, " ", pointerState.y
    pointerState.buttonPending = false

  echo "[Pointer] Frame event done."

proc onAxisSource(data: pointer, pointer: ptr wl_pointer, axisSource: uint32) {.cdecl.} =
  discard

proc onAxisStop(data: pointer, pointer: ptr wl_pointer, time, axis: uint32) {.cdecl.} =
  discard

proc onAxisDiscrete(data: pointer, pointer: ptr wl_pointer, axis: uint32, discrete: int32) {.cdecl.} =
  discard

let pointerListener = wlPointerListener(
  enter: pointerHandleEnter,
  leave: pointerHandleLeave, # Handle leave if needed
  motion: pointerHandleMotion,
  button: pointerHandleButton,
  axis: pointerHandleScroll, # Handle scroll if needed
  frame: pointerHandleFrame,
  axis_source: onAxisSource,
  axis_stop: onAxisStop,
  axis_discrete: onAxisDiscrete,
)

# Get Seat
proc seatCapabilities(data: pointer, seat: ptr wl_seat, capabilities: uint32) {.cdecl.} =
  let pointer = wl_seat_get_pointer(seat)
  if pointer == nil:
    echo "Error: Failed to get wayland pointer"

  # Add pointer listener
  discard pointer.wl_pointer_add_listener(addr pointerListener, seat)

proc seatName(data: pointer, seat: ptr wl_seat, name: ConstCStr) {.cdecl.} =
  echo "[Seat] Name: ", $name, "\n"

# Needed to convert 'const char*name' to cstring
type CSeatNameCallback = proc (d: pointer, s: ptr wl_seat, n: cstring) {.cdecl.}

let seatListener = wl_seat_listener(
  capabilities: seatCapabilities,
  name: cast[CSeatNameCallback](seatName)
)

# ========================================================================================
#
#                                   Leve Panel
#                          version 1.0.2 by Mac_Taylor
#
# ========================================================================================

import
  pkg/nayland/types/protocols/core/[compositor, registry, shm, shm_pool, surface, buffer, output],
  pkg/nayland/bindings/protocols/[core, xdg_shell, xdg_decoration_unstable_v1],
  pkg/nayland/types/protocols/xdg_shell/[wm_base, xdg_surface, xdg_toplevel],
  pkg/nayland/types/protocols/xdg_decoration/prelude,
  pkg/nayland/bindings/protocols/[xdg_output_unstable_v1],
  pkg/nayland/bindings/protocols/[wlr_layer_shell_unstable_v1],
  pkg/nayland/types/protocols/wlr/layer_shell/prelude,
  pkg/nayland/bindings/[libwayland]

import std/[os, posix, strutils, osproc, times]
import parsetoml
import pixie

proc prepare_read*(display: ptr wl_display): cint {.
    importc: "wl_display_prepare_read", dynlib: "libwayland-client.so".}
proc dispatch_pending*(display: ptr wl_display): cint {.
    importc: "wl_display_dispatch_pending", dynlib: "libwayland-client.so".}
proc read_events*(display: ptr wl_display): cint {.
    importc: "wl_display_read_events", dynlib: "libwayland-client.so".}
proc cancel_read*(display: ptr wl_display) {.importc: "wl_display_cancel_read",
    dynlib: "libwayland-client.so".}

# Import system calls
proc timerfd_create(clockid, flags: cint): cint {.importc, header: "<sys/timerfd.h>".}
proc timerfd_settime(
  fd: cint, flags: cint, newVal: ptr ITimerspec, oldVal: ptr ITimerspec
): cint {.importc, header: "<sys/timerfd.h>".}

type PanelPos = enum
  top
  bottom
  left
  right

type DisplayInfo = ref object
  name: string
  pos_x: int32
  pos_y: int32
  width: int32
  height: int32
  scale: int32

type LevePanel = ref object
  display: ptr wl_display
  output: ptr wl_output
  outputMan: ptr zxdgOutputManagerV1
  registry: ptr wl_registry
  seat: ptr wl_seat
  compositor: ptr wl_compositor
  pixelData: ptr UncheckedArray[uint32]
  shMem: ptr wl_shm
  buffer: ptr wl_buffer
  surface: ptr wl_surface
  layerSurface: ptr zwlrLayerSurfaceV1
  layerShell: ptr zwlrLayerShellV1
  size: int32 = 46
  iconSize = 32
  pos: PanelPos = PanelPos.bottom
  color: string = "#070C1E"
  mouse_x: float
  mouse_y: float
  scrollUpCmd: string
  scrollDownCmd: string

type WidgetType = enum
  favorite
  clock
  volume
  power

type PanelItem = object
  widget: WidgetType
  icon: string
  exec: string
  terminal: bool

var leftItems: seq[PanelItem]
var rightItems: seq[PanelItem]

type CallBack = tuple
  event: string
  handler: proc(data: pointer)

type CallBacks = seq[CallBack]

type Widget = ref object
  widgetType: WidgetType
  startPos: array[2, int]
  endPos: array[2, int]
  img: Image
  callBacks: CallBacks

var widgets: seq[Widget] = @[]
var  displayInfo = DisplayInfo(name: "Unknown")
var p = LevePanel()

proc updateWidget(w: ptr Widget)
include "leve-panel"/[config, favorites, clock, volume, power, panel]

# ----------------------------------------------------------------------------------------
#                                    Get Output
# ----------------------------------------------------------------------------------------

proc xdgOutputLogicalPos(
    data: pointer, xdgOutput: ptr zxdgOutputV1, width: int32, height: int32
) {.cdecl.} =
  let info = cast[DisplayInfo](data)
  info.pos_x = width
  info.pos_y = height
  echo "XDG Output [", info.name, "] Logical Pos: ", width, "x", height

proc xdgOutputLogicalSize(
    data: pointer, xdgOutput: ptr  zxdgOutputV1, width: int32, height: int32
) {.cdecl.} =
  let info = cast[DisplayInfo](data)
  info.width = width
  info.height = height
  echo "XDG Output [", info.name, "] Logical Size: ", width, "x", height

proc xdgOutputDone(data: pointer, xdgOutput: ptr  zxdgOutputV1) {.cdecl.} =
  let info = cast[DisplayInfo](data)
  echo "XDG Output [", info.name, "] Configuration finalized."

# Initialize listeners
var xdgOutputListener =  zxdgOutputV1Listener(
  logical_position: xdgOutputLogicalPos, # Handle if needed
  logical_size: xdgOutputLogicalSize,
  done: xdgOutputDone,
  name: nil, # Handle if needed
  description: nil, # Handle if needed
)

proc bindOutput(output: ptr wl_output, manager: ptr zxdgOutputManagerV1) =
  # Create the XDG Output object for the given Wayland output
  let xdgOutput = zxdg_output_manager_v1_get_xdg_output(manager, output)
  if xdgOutput == nil:
    echo "Error: Failed to create XDG Output"

  discard xdgOutput.zxdg_output_v1_add_listener(addr xdgOutputListener, cast[pointer]( displayInfo))

# ----------------------------------------------------------------------------------------
#                                    Callbacks
# ----------------------------------------------------------------------------------------

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

# Scroll on Surface
proc pointerHandleScroll(
    data: pointer, pointer: ptr wl_pointer, time: uint32, axis: uint32, value: wl_fixed
) {.cdecl.} =
  echo "Pointer scroll on surface"

  echo axis
  echo value

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

# ----------------------------------------------------------------------------------------
#                                    Registry
# ----------------------------------------------------------------------------------------

proc globalRegistry(
    data: pointer, registry: ptr wl_registry, id: uint32, intf: ConstCStr, ver: uint32
) {.cdecl.} =
  let panel = cast[ptr LevePanel](data)

  if $(intf) == "zwlr_layer_shell_v1":
    panel.layerShell = cast[ptr zwlrLayerShellV1](registry.wl_registry_bind(
      id, addr zwlr_layer_shell_v1_interface, 1
    ))
  elif $(intf) == "zxdg_output_manager_v1":
    panel.outputMan = cast[ptr zxdgOutputManagerV1](registry.wl_registry_bind(
      id, addr zxdg_output_manager_v1_interface, 1
    ))
  elif $(intf) == "wl_output":
    panel.output = cast[ptr wlOutput](registry.wl_registry_bind(id, addr wl_output_interface, 1))
  elif $(intf) == "wl_shm":
    panel.shMem = cast[ptr wl_shm](registry.wl_registry_bind(id, addr wl_shm_interface, 1))
  elif $(intf) == "wl_compositor":
    panel.compositor =
      cast[ptr wl_compositor](registry.wl_registry_bind(id, addr wl_compositor_interface, 4))
  elif $(intf) == "wl_seat":
    panel.seat = cast[ptr  wl_seat](registry.wl_registry_bind(id, addr wl_seat_interface, 1))
    #panel.seat.addListener(addr pointerListener, nil)

proc removeGlobalRegistry(data: pointer, registry: ptr wl_registry, name: uint32) {.cdecl.} =
  # This space deliberately left blank
  discard

# ----------------------------------------------------------------------------------------
#                                    Main
# ----------------------------------------------------------------------------------------

proc main() =
  # Parse config and get favorite apps
  let config = initFile("config.toml", defaultConfig)
  parseConfig(config)

  # Connect to the Display
  p.display = wl_display_connect(nil)
  if p.display == nil:
    echo "Error: Failed to connect to Wayland display"
    return

  # Get registry
  p.registry = wl_display_get_registry(p.display)
  if p.registry == nil:
    echo "Error: Failed to get registry"
    #destroy(p.display)
    return

  # Add registry listener
  let registry_listener =
    wlRegistryListener(global: globalRegistry, global_remove: removeGlobalRegistry)
  discard cast[ptr wl_registry](p.registry).wl_registry_add_listener(addr registry_listener, addr p)
  #discard wl_registry_add_listener(handle, listeners.addr, cast[ptr RegistryObj](reg))
  if p.display == nil:
    echo "Error: Failed to connect to Wayland display"

  discard wl_display_roundtrip(p.display)

  # Check if required interfaces were bound
  if p.compositor == nil:
    echo "Error: Wayland compositor not available"
    #destroy(p.registry)
    #destroy(p.display)
    return

  if p.output == nil:
    echo "Error: Failed to get output"
    #destroy(p.registry)
    #destroy(p.display)
    return

  # Bind output to get display dimensions
  p.output.bindOutput(p.outputMan)

  # Create surface
  p.surface = p.compositor.wl_compositor_create_surface()
  if p.surface == nil:
    echo "Error: Failed to create wayland surface"
    #destroy(p.registry)
    #destroy(p.display)
    return

  # Add surface to layer
  p.layerSurface = cast[ptr zwlr_layer_surface_v1](zwlr_layer_shell_v1_get_layer_surface(
    cast[ptr zwlr_layer_shell_v1](p.layerShell),
    p.surface,
    nil,
    cast[uint32](top),
    cstring("leve-panel"),
  ))
  if p.layerSurface == nil:
    echo "Error: Failed to create layer surface"
    #destroy(p.surface)
    #destroy(p.registry)
    #destroy(p.display)
    return

  cast[ptr zwlr_layer_surface_v1](p.layerSurface).zwlr_layer_surface_v1_set_size(uint32(displayInfo.width), uint32(p.size))

  # Push other windows out of the way
  p.layerSurface.zwlr_layer_surface_v1_set_exclusive_zone(p.size)

  # Set position on the screen
  case p.pos
  of PanelPos.top:
    p.layerSurface.zwlr_layer_surface_v1_set_anchor(13)
  of PanelPos.bottom:
    p.layerSurface.zwlr_layer_surface_v1_set_anchor(14)
  of PanelPos.left:
    p.layerSurface.zwlr_layer_surface_v1_set_anchor(7)
  of PanelPos.right:
    p.layerSurface.zwlr_layer_surface_v1_set_anchor(11)

  let surface_listener = zwlrLayerSurfaceV1Listener(configure: configureSurface)
  discard p.layerSurface.zwlr_layer_surface_v1_add_listener(addr surface_listener, addr p)

  # Get Seat (Seat holds the pointer)
  let seat_listener = wl_seat_listener(capabilities: seatCapabilities, name: nil)
  discard p.seat.wl_seat_add_listener(addr seat_listener, nil)

  # Get Pointer
  let pointer = wl_seat_get_pointer(p.seat)
  if pointer == nil:
    echo "Error: Failed to get pointer"

  # Add pointer listener
  discard pointer.wl_pointer_add_listener(addr pointerListener, nil)

  # Commit surface
  p.surface.wl_surface_commit()

  # --- Timer Setup ---
  let tfd = timerfd_create(CLOCK_MONOTONIC, 0)
  var spec: Itimerspec
  spec.it_interval.tv_sec = posix.Time(1) # Repeat every 1s
  #spec.it_interval.tv_nsec = 500_000_000 # Repeat every 0.5s
  spec.it_value.tv_sec = posix.Time(1) # Start in 1s
  discard timerfd_settime(tfd, 0, addr spec, nil)

  let wl_fd = wl_display_get_fd(p.display)

  # --- The Event Loop ---
  var fds: array[2, TPollfd]
  fds[0] = TPollfd(fd: wl_fd, events: POLLIN)
  fds[1] = TPollfd(fd: tfd, events: POLLIN)

  echo "Nim Wayland Clock Running..."

  while true:
    # 1. Prepare Wayland
    while prepareRead(p.display) != 0:
      discard dispatchPending(p.display)
    discard wl_display_flush(p.display)

    # 2. Poll both FDs (infinite timeout)
    if poll(addr fds[0], 2, -1) < 0:
      break

    # 3. Handle Wayland Events
    if (fds[0].revents and POLLIN) != 0:
      discard read_events(p.display)
      discard dispatchPending(p.display)
    else:
      cancel_read(p.display)

    # 4. Handle Timer
    if (fds[1].revents and POLLIN) != 0:
      var expirations: uint64
      discard read(tfd, addr expirations, sizeof(expirations))

      # Redraw logic
      echo "Tick: ", now().format("HH:mm:ss")

      if now().second == 0:
        for widget in widgets:
          if widget.widgetType == WidgetType.clock:
            widget.img = newClockImg()
            updateWidget(addr widget)
        p.surface.wl_surface_commit()
      # Update volume state and Image
      cur_vol = getVolume()
      volMute = getMute()
      if volState == getVolState():
        continue
      volState = getVolState()
      for widget in widgets:
        if widget.widgetType == WidgetType.volume:
          widget.img = newVolImg()
          updateWidget(addr widget)
      p.surface.wl_surface_commit()


  # Cleanup
  discard munmap(cast[pointer](p.pixelData), displayInfo.width * 4 * p.size)

  p.seat.wl_seat_release()

  # Event Loop
  #while dispatch(p.display) != -1:
  # Wait for events (resize, close, etc.)
  #discard

when isMainModule:
  main()

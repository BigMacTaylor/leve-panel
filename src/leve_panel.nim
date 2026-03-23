# ========================================================================================
#
#                                   Leve Panel
#                          version 1.0.1 by Mac_Taylor
#
# ========================================================================================

import wayland/native as wl
import wayland/protocols/unstable/xdgoutputunstable/v1/client
import wayland/protocols/unstable/wlrlayershell/v1/client
import std/[os, posix, strutils, osproc, times]
import parsetoml
import pixie

# Import system calls
proc timerfd_create(clockid, flags: cint): cint {.importc, header: "<sys/timerfd.h>".}
proc timerfd_settime(
  fd: cint, flags: cint, newVal: ptr ITimerspec, oldVal: ptr ITimerspec
): cint {.importc, header: "<sys/timerfd.h>".}

const defaultConfig =
  """
#          Leve Panel Default Config
#

# Panel Settings
[Panel]
pos = "bottom"
color = "#070C1E"
size = 46
icon_size = 32

# Favorite Apps
[[app]]
name = "Menu"
icon = "menu.png"
exec = "griddle"
terminal = false

[[app]]
name = "Files"
icon = "folder-blue.png"
exec = "pcmanfm"
terminal = false

[[app]]
name = "Terminal"
icon = "terminal.png"
exec = "foot"
terminal = false

[[app]]
name = "Browser"
icon = "google-chrome.png"
exec = "google-chrome"
terminal = false
"""

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
  display: ptr wl.Display
  output: ptr Output
  outputMan: ptr ZxdgOutputManagerV1
  registry: ptr wl.Registry
  seat: ptr wl.Seat
  compositor: ptr wl.Compositor
  memBuffer: ptr wl.Shm
  surface: ptr wl.Surface
  layerSurface: ptr ZwlrLayerSurfaceV1
  layerShell: ptr ZwlrLayerShellV1
  size: int32 = 46
  iconSize = 36
  pos: PanelPos = PanelPos.bottom
  color: string = "#070C1E"
  mouse_x: float
  mouse_y: float

type Favorite = object
  name: string
  icon: string
  exec: string
  terminal: bool

var favorites: seq[Favorite]

type CallBack = tuple
  event: string
  handler: proc(data: pointer)

type CallBacks = seq[CallBack]

type Widget = object
  startPos: array[2, int]
  endPos: array[2, int]
  img: Image
  callBacks: CallBacks
  #data: pointer

var widgets: seq[Widget] = @[]
var display = DisplayInfo(name: "Unknown")
var p = LevePanel()


proc updateFrame(panel: LevePanel)
include "leve-panel"/[config, favorites, clock, volume, panel]

# ----------------------------------------------------------------------------------------
#                                    Get Output
# ----------------------------------------------------------------------------------------

proc xdgOutputLogicalPos(
    data: pointer, xdgOutput: ptr ZxdgOutputV1, width: int32, height: int32
) =
  let info = cast[DisplayInfo](data)
  info.pos_x = width
  info.pos_y = height
  echo "XDG Output [", info.name, "] Logical Pos: ", width, "x", height

proc xdgOutputLogicalSize(
    data: pointer, xdgOutput: ptr ZxdgOutputV1, width: int32, height: int32
) =
  let info = cast[DisplayInfo](data)
  info.width = width
  info.height = height
  echo "XDG Output [", info.name, "] Logical Size: ", width, "x", height

proc xdgOutputDone(data: pointer, xdgOutput: ptr ZxdgOutputV1) =
  let info = cast[DisplayInfo](data)
  echo "XDG Output [", info.name, "] Configuration finalized."

# Initialize listeners
var xdgOutputListener = ZxdgOutputV1Listener(
  logical_position: xdgOutputLogicalPos, # Handle if needed
  logical_size: xdgOutputLogicalSize,
  done: xdgOutputDone,
  name: nil, # Handle if needed
  description: nil, # Handle if needed
)

proc bindOutput(output: ptr Output, manager: ptr ZxdgOutputManagerV1) =
  # Create the XDG Output object for the given Wayland output
  let xdgOutput = getXdgOutput(manager, output)
  if xdgOutput == nil:
    echo "Error: Failed to create XDG Output"

  discard xdgOutput.addListener(addr xdgOutputListener, cast[pointer](display))

# ----------------------------------------------------------------------------------------
#                                    Callbacks
# ----------------------------------------------------------------------------------------

proc seatCapabilities(data: pointer, seat: ptr Seat, capabilities: uint32) =
  discard

proc fixedToDouble(f: Fixed): float =
  return float(f / 256)

# Pointer Motion
proc pointerHandleMotion(
    data: pointer, pointer: ptr Pointer, time: uint32, surfaceX: Fixed, surfaceY: Fixed
) =
  # Convert Wayland fixed point to float/integer
  #p.pointer.event = Event.motion
  #p.pointer.pos_x = fixedToDouble(surfaceX)
  #p.pointer.pos_y = fixedToDouble(surfaceY)

  p.mouse_x = fixedToDouble(surfaceX)
  p.mouse_y = fixedToDouble(surfaceY)
  echo "Mouse Moved: ", p.mouse_x, ", ", p.mouse_y

proc isWithin(w: Widget, x, y: int): bool =
  if x >= w.startPos[0] and x <= w.endPos[0] and y >= w.startPos[1] and y <= w.endPos[1]:
    echo "Within bounds !"
    return true

# Button Click
proc pointerHandleButton(
    data: pointer,
    pointer: ptr Pointer,
    serial: uint32,
    time: uint32,
    button: uint32,
    state: uint32,
) =

  if state == 1:
    echo "Button clicked: ", button, " ", p.mouse_x, ", ", p.mouse_y

  if state == 1 and button == 272:
    for widget in widgets:
      if widget.isWithin(int(p.mouse_x), int(p.mouse_y)):
        for cb in widget.callBacks:
          if cb.event == "click_l":
            echo "clicked"
            cb.handler(nil)
            return # Found it, stop looking

  if state == 1 and button == 273:
    for widget in widgets:
      if widget.isWithin(int(p.mouse_x), int(p.mouse_y)):
        for cb in widget.callBacks:
          if cb.event == "click_r":
            echo "clicked"
            cb.handler(nil)
            return # Found it, stop looking

  if state == 1 and button == 274:
    for widget in widgets:
      if widget.isWithin(int(p.mouse_x), int(p.mouse_y)):
        for cb in widget.callBacks:
          if cb.event == "click_m":
            echo "clicked"
            cb.handler(nil)
            return # Found it, stop looking


# Enter Surface
proc pointerHandleEnter(
    data: pointer,
    pointer: ptr Pointer,
    serial: uint32,
    surface: ptr Surface,
    surfaceX: Fixed,
    surfaceY: Fixed,
) =
  #p.pointer.event = Event.enter
  echo "Pointer entered surface"

# Leave Surface
proc pointerHandleLeave(
    data: pointer, pointer: ptr Pointer, serial: uint32, surface: ptr Surface
) =
  #p.pointer.event = Event.leave
  echo "Pointer left surface"

# Scroll on Surface
proc pointerHandleScroll(
    data: pointer, pointer: ptr Pointer, time: uint32, axis: uint32, value: Fixed
) =
  echo "Pointer scroll on surface"

  echo axis
  echo value

  if axis == 0 and value == -3840: # scroll up
    for widget in widgets:
      if widget.isWithin(int(p.mouse_x), int(p.mouse_y)):
        for cb in widget.callBacks:
          if cb.event == "scroll_up":
            echo "scroll_up"
            cb.handler(nil)
            return # Found it, stop looking

  if axis == 0 and value == 3840: # scroll down
    for widget in widgets:
      if widget.isWithin(int(p.mouse_x), int(p.mouse_y)):
        for cb in widget.callBacks:
          if cb.event == "scroll_down":
            echo "scroll_down"
            cb.handler(nil)
            return # Found it, stop looking

# Setup Pointer Listener
var pointerListener = wl.PointerListener(
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
    data: pointer, registry: ptr wl.Registry, id: uint32, intf: cstring, ver: uint32
) =
  let panel = cast[ptr LevePanel](data)

  if intf == "zwlr_layer_shell_v1":
    panel.layerShell = cast[ptr ZwlrLayerShellV1](registry.bind(
      id, addr zwlr_layer_shell_v1_interface, 1
    ))
  elif intf == "zxdg_output_manager_v1":
    panel.outputMan = cast[ptr ZxdgOutputManagerV1](registry.bind(
      id, addr zxdg_output_manager_v1_interface, 1
    ))
  elif intf == "wl_output":
    panel.output = cast[ptr Output](registry.bind(id, addr wl_output_interface, 1))
  elif intf == "wl_shm":
    panel.memBuffer = cast[ptr wl.Shm](registry.bind(id, addr wl_shm_interface, 1))
  elif intf == "wl_compositor":
    panel.compositor =
      cast[ptr wl.Compositor](registry.bind(id, addr wl_compositor_interface, 4))
  elif intf == "wl_seat":
    panel.seat = cast[ptr wl.Seat](registry.bind(id, addr wl_seat_interface, 1))
    #panel.seat.addListener(addr pointerListener, nil)

proc removeGlobalRegistry(data: pointer, registry: ptr wl.Registry, name: uint32) =
  # This space deliberately left blank
  discard

# ----------------------------------------------------------------------------------------
#                                    Main
# ----------------------------------------------------------------------------------------

proc main() =
  # Parse config and get favorite apps
  let config = initFile("config.toml", defaultConfig)
  favorites = parseConfig(config)

  # Connect to the Display
  p.display = connectDisplay(nil)
  if p.display == nil:
    echo "Error: Failed to connect to Wayland display"
    return

  # Get registry
  p.registry = getRegistry(p.display)
  if p.registry == nil:
    echo "Error: Failed to get registry"
    destroy(p.display)
    return

  # Add registry listener
  let registry_listener =
    wl.RegistryListener(global: globalRegistry, global_remove: removeGlobalRegistry)
  discard p.registry.addListener(addr registry_listener, addr p)
  discard roundtrip(p.display)

  # Check if required interfaces were bound
  if p.compositor == nil:
    echo "Error: Wayland compositor not available"
    destroy(p.registry)
    destroy(p.display)
    return

  if p.output == nil:
    echo "Error: Failed to get output"
    destroy(p.registry)
    destroy(p.display)
    return

  # Bind output to get display dimensions
  p.output.bindOutput(p.outputMan)

  # Create surface
  p.surface = p.compositor.createSurface()
  if p.surface == nil:
    echo "Error: Failed to create wayland surface"
    destroy(p.registry)
    destroy(p.display)
    return

  # Add surface to layer
  p.layerSurface = getLayerSurface(
    p.layerShell,
    p.surface,
    nil,
    ZwlrLayerShellV1Layer.layer_top.ord,
    cstring("leve-panel"),
  )
  if p.layerSurface == nil:
    echo "Error: Failed to create layer surface"
    destroy(p.surface)
    destroy(p.registry)
    destroy(p.display)
    return

  p.layerSurface.setSize(uint32(display.width), uint32(p.size))

  # Push other windows out of the way
  p.layerSurface.setExclusiveZone(p.size)

  # Set position on the screen
  case p.pos
  of PanelPos.top:
    p.layerSurface.setAnchor(13)
  of PanelPos.bottom:
    p.layerSurface.setAnchor(14)
  of PanelPos.left:
    p.layerSurface.setAnchor(7)
  of PanelPos.right:
    p.layerSurface.setAnchor(11)

  let surface_listener = ZwlrLayerSurfaceV1Listener(configure: configureSurface)
  discard p.layerSurface.addListener(addr surface_listener, addr p)

  # Get Seat (Seat holds the pointer)
  let seat_listener = SeatListener(capabilities: seatCapabilities, name: nil)
  discard p.seat.addListener(addr seat_listener, nil)

  # Get Pointer
  let pointer = getPointer(p.seat)
  if pointer == nil:
    echo "Error: Failed to get pointer"

  # Add pointer listener
  discard pointer.addListener(addr pointerListener, nil)

  # Commit surface
  p.surface.commit()

  # --- Timer Setup ---
  let tfd = timerfd_create(CLOCK_MONOTONIC, 0)
  var spec: Itimerspec
  spec.it_interval.tv_sec = posix.Time(1) # Repeat every 1s
  spec.it_value.tv_sec = posix.Time(1) # Start in 1s
  discard timerfd_settime(tfd, 0, addr spec, nil)

  let wl_fd = get_fd(p.display)

  # --- The Event Loop ---
  var fds: array[2, TPollfd]
  fds[0] = TPollfd(fd: wl_fd, events: POLLIN)
  fds[1] = TPollfd(fd: tfd, events: POLLIN)

  echo "Nim Wayland Clock Running..."

  while true:
    # 1. Prepare Wayland
    while prepareRead(p.display) != 0:
      discard dispatchPending(p.display)
    discard flush(p.display)

    # 2. Poll both FDs (infinite timeout)
    if poll(addr fds[0], 2, -1) < 0:
      break

    # 3. Handle Wayland Events
    if (fds[0].revents and POLLIN) != 0:
      discard read_events(p.display)
      discard dispatchPending(p.display)
    else:
      cancel_read(p.display)

    # 4. Handle Timer (The Clock Tick)
    if (fds[1].revents and POLLIN) != 0:
      var expirations: uint64
      discard read(tfd, addr expirations, sizeof(expirations))

      # Redraw logic here
      #echo "Tick: ", now().format("HH:mm:ss")

      if now().second == 0:
        p.updateFrame()


  # Event Loop
  #while dispatch(p.display) != -1:
  # Wait for events (resize, close, etc.)
  #discard

  #p.seat.release()

when isMainModule:
  main()

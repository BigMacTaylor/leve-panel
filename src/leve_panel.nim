# ========================================================================================
#
#                                   Leve Panel
#                          version 1.0.7 by Mac_Taylor
#
# ========================================================================================

import
  pkg/nayland/types/protocols/core/[shm_pool],
  pkg/nayland/bindings/protocols/[core, xdg_shell, xdg_decoration_unstable_v1],
  pkg/nayland/bindings/protocols/[wlr_layer_shell_unstable_v1],
  pkg/nayland/bindings/protocols/[cursor_shape_v1, tablet_v2],
  pkg/nayland/bindings/[libwayland]

import "wayland"/[xdg_output_unstable_v1]
import "wayland"/[ext_workspace_v1]

import std/[os, posix, strutils, osproc, times]
import std/[nativesockets, net, monotimes]
import subprocess
import parsetoml
import pixie

proc prepare_read*(display: ptr wl_display): cint {.
    importc: "wl_display_prepare_read", dynlib: "libwayland-client.so.0".}
proc dispatch_pending*(display: ptr wl_display): cint {.
    importc: "wl_display_dispatch_pending", dynlib: "libwayland-client.so.0".}
proc read_events*(display: ptr wl_display): cint {.
    importc: "wl_display_read_events", dynlib: "libwayland-client.so.0".}
proc cancel_read*(display: ptr wl_display) {.importc: "wl_display_cancel_read",
    dynlib: "libwayland-client.so.0".}

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
  changed: bool

type LevePanel = ref object
  display: ptr wl_display
  output: ptr wl_output
  outputMan: ptr zxdgOutputManagerV1
  registry: ptr wl_registry
  seat: ptr wl_seat
  ws_manager: ptr ext_workspace_manager_v1
  cursor_manager: ptr wp_cursor_shape_manager_v1
  cursor: ptr wp_cursor_shape_device_v1
  compositor: ptr wl_compositor
  pixelData: ptr UncheckedArray[uint32]
  pixelDataSize: int32
  shMem: ptr wl_shm
  buffer: ptr wl_buffer
  surface: ptr wl_surface
  layerSurface: ptr zwlrLayerSurfaceV1
  layerShell: ptr zwlrLayerShellV1
  size: int32 = 46
  iconSize: int32 = 32
  pos: PanelPos = PanelPos.bottom
  color: string = "#070C1E"
  mouse_x: float
  mouse_y: float
  scrollUpCmd: string
  scrollDownCmd: string

type VolState = enum
  mute
  low
  med
  high

type Indicator = enum
  num
  numbers
  dots

type WidgetType = enum
  favorite
  clock
  volume
  menu
  power
  desktop

type PanelItem = object
  widget: WidgetType
  style: Indicator
  icon: string
  exec: string
  terminal: bool

type Event = enum
  click_l
  click_r
  click_m
  scroll_up
  scroll_down

type CallBack = tuple
  event: Event
  handler: proc(data: pointer)

type CallBacks = seq[CallBack]

type Widget = ref object
  widgetType: WidgetType
  startPos: array[2, int]
  endPos: array[2, int]
  img: Image
  callBacks: CallBacks

type WsFlag = enum
  active
  urgent
  hidden

type WsFlags = set[WsFlag]

type WorkspaceData = object
  handle: ptr ext_workspace_handle_v1
  num: int
  name: string
  state: WsFlags

type imgProc = proc (curWS: int): Image

var newDesktopImg: imgProc
var leftItems: seq[PanelItem]
var centerItems: seq[PanelItem]
var rightItems: seq[PanelItem]
var widgets: seq[Widget] = @[]
var workspaces: seq[WorkspaceData] = @[]
var displayInfo = DisplayInfo(name: "Unknown")
var p = LevePanel()
setCurrentDir(getHomeDir())

proc updateWidget(w: ptr Widget)
include "leve-panel"/[config, favorites, clock, volume, menu, power]
include "leve-panel"/[workspaces, sway, desktop_indicator, panel, output, callbacks]

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
    panel.seat = cast[ptr wl_seat](registry.wl_registry_bind(id, addr wl_seat_interface, 1))
    #panel.seat.addListener(addr pointerListener, nil)
  elif $(intf) == "wp_cursor_shape_manager_v1":
    panel.cursor_manager = cast[ptr wp_cursor_shape_manager_v1](registry.wl_registry_bind(id, addr wp_cursor_shape_manager_v1_interface, 1))
  elif $(intf) == "ext_workspace_manager_v1":
    panel.ws_manager = cast[ptr ext_workspace_manager_v1](registry.wl_registry_bind(id, addr ext_workspace_manager_v1_interface, 1))
    discard panel.ws_manager.ext_workspace_manager_v1_add_listener(addr managerListener, nil)

proc removeGlobalRegistry(data: pointer, registry: ptr wl_registry, name: uint32) {.cdecl.} =
  # This space deliberately left blank
  discard

# ----------------------------------------------------------------------------------------
#                                    Main
# ----------------------------------------------------------------------------------------

proc main() =
  echo "\nStarting Leve-Panel...\n"

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
  discard p.registry.wl_registry_add_listener(addr registry_listener, addr p)

  if p.display == nil:
    echo "Error: Failed to connect to Wayland display"

  discard wl_display_roundtrip(p.display)

  # Check if required interfaces were bound
  if p.compositor == nil:
    echo "Error: Wayland compositor not available"
    wl_registry_destroy(p.registry)
    #destroy(p.display)
    return

  if p.output == nil:
    echo "Error: Failed to get output"
    wl_registry_destroy(p.registry)
    #destroy(p.display)
    return

  # Bind output to get display dimensions
  p.output.bindOutput(p.outputMan)

  # Create surface
  p.surface = p.compositor.wl_compositor_create_surface()
  if p.surface == nil:
    echo "Error: Failed to create wayland surface"
    wl_registry_destroy(p.registry)
    #destroy(p.display)
    return

  if p.layerShell == nil:
    echo "Error: Failed to create layer shell"
    echo "Are you running Gnome?... yuck!\n"
    wl_surface_destroy(p.surface)
    wl_registry_destroy(p.registry)
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
    wl_surface_destroy(p.surface)
    wl_registry_destroy(p.registry)
    #destroy(p.display)
    return

  if p.pos == top or p.pos == bottom:
    cast[ptr zwlr_layer_surface_v1](p.layerSurface).zwlr_layer_surface_v1_set_size(uint32(displayInfo.width), uint32(p.size))
  else:
    cast[ptr zwlr_layer_surface_v1](p.layerSurface).zwlr_layer_surface_v1_set_size(uint32(p.size), uint32(displayInfo.height))

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

  let surface_listener = zwlrLayerSurfaceV1Listener(
    configure: configureSurface,
    closed: surfaceClose
    )
  discard p.layerSurface.zwlr_layer_surface_v1_add_listener(addr surface_listener, addr p)

  # Get Seat (Seat holds the pointer)
  let seat_listener = wl_seat_listener(capabilities: seatCapabilities, name: nil)
  discard p.seat.wl_seat_add_listener(addr seat_listener, nil)

  # Get Pointer
  let pointer = wl_seat_get_pointer(p.seat)
  if pointer == nil:
    echo "Error: Failed to get wayland pointer"

  # Add pointer listener
  discard pointer.wl_pointer_add_listener(addr pointerListener, nil)

  # Commit surface
  p.surface.wl_surface_commit()

  # ----------------------------------------------------------------------------------------
  #                                  Setup FDs
  # ----------------------------------------------------------------------------------------

  # Get Wayland FD
  let wl_fd = wl_display_get_fd(p.display)

  # Setup Timer FD
  let time_fd = timerfd_create(CLOCK_MONOTONIC, 0)
  var spec: Itimerspec
  spec.it_interval.tv_sec = posix.Time(1) # Repeat every 1s
  #spec.it_interval.tv_nsec = 100_000_000 # Repeat every 0.1s
  spec.it_value.tv_sec = posix.Time(1) # Start in 1s
  discard timerfd_settime(time_fd, 0, addr spec, nil)

  # Get Sway FD, returns -1 if not running
  let sway_fd: cint = getSwayFD()

  var fds: array[3, TPollfd]
  fds[0] = TPollfd(fd: wl_fd, events: POLLIN)
  fds[1] = TPollfd(fd: time_fd, events: POLLIN)
  fds[2] = TPollfd(fd: sway_fd, events: POLLIN)

  #var buffer = newString(4096)
  var curWS = 0
  var timeOut: cint = -1
  var swayEventsReady = false

  echo "\nLeve-Panel: Clock Running... \n"

  # ----------------------------------------------------------------------------------------
  #                                  Event Loop
  # ----------------------------------------------------------------------------------------

  while true:
    # Prepare Wayland
    while prepareRead(p.display) != 0:
      discard dispatchPending(p.display)
    discard wl_display_flush(p.display)

    # Poll FDs (timeout of -1 means block indefinitely)
    if poll(addr fds[0], 3, timeOut) < 0:
      break

    # Handle Wayland Events
    if (fds[0].revents and POLLIN) != 0:
      discard read_events(p.display)
      discard dispatchPending(p.display)
    else:
      cancel_read(p.display)

    # Handle timer
    if (fds[1].revents and POLLIN) != 0:
      var expirations: uint64
      discard read(time_fd, addr expirations, sizeof(expirations))

      echo ""
      echo "Tick: ", now().format("HH:mm:ss")

      # Update Clock widget
      if now().second == 0:
        for widget in widgets:
          if widget.widgetType == WidgetType.clock:
            widget.img = newClockImg()
            updateWidget(addr widget)
        p.surface.wl_surface_commit()

      # Check pipe data
      if volProcess.hasDataStdout():
        echo "Update volume state"
        volMute = getMute()
        cur_vol = getVolume()

        # Read all content to "clear" it from buffer
        discard volProcess.readStdout()

        # Check widget state
        if volState != getVolState():
          # Update Volume widget
          volState = getVolState()
          for widget in widgets:
            if widget.widgetType == WidgetType.volume:
              widget.img = newVolImg()
              updateWidget(addr widget)
          p.surface.wl_surface_commit()

    # Handle Sway IPC Events
    if (fds[2].revents and POLLIN) != 0:
      # Read the 14-Byte Response Header
      let headerBytes = readExact(sway_fd, 14)

      # Verify magic string
      if headerBytes[0..5] != "i3-ipc":
        echo("Error: Invalid IPC magic string received.")
      else:
        # Get payload length from bytes 6 to 9 (Little Endian)
        var replyLen: uint32
        copyMem(addr replyLen, addr headerBytes[6], 4)

        # Get message type from bytes 10 to 13
        var replyType: uint32
        copyMem(addr replyType, addr headerBytes[10], 4)

        # Read JSON Payload
        let json = readExact(sway_fd, int(replyLen))
        curWS = getWsFromJson(json)
        swayEventsReady = true
        timeOut = 5
        continue

    # Check if Sway Events are ready
    if swayEventsReady:
      # Update desktop indicator widget
      for widget in widgets:
        if widget.widgetType == WidgetType.desktop:
          widget.img = newDesktopImg(curWS)
          updateWidget(addr widget)
      p.surface.wl_surface_commit()
      swayEventsReady = false
      timeOut = -1

  # Cleanup
  discard munmap(cast[pointer](p.pixelData), displayInfo.width * 4 * p.size)

  p.seat.wl_seat_release()

proc cleanup() {.noconv.} =
  echo "Program interrupted by user"
  echo "Performing cleanup..."
  volProcess.close()

  quit()

when isMainModule:
  setControlCHook(cleanup)

  let config = initFile("config.toml", defaultConfig)
  parseConfig(config)

  main()


# ========================================================================================
#
#                                   Leve Panel
#                          version 1.0.5 by Mac_Taylor
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
import std/[nativesockets, net, monotimes]
import subprocess
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

const
  IpcTypeSubscribe = 2'u32
  IPC_MAGIC = "i3-ipc"

type PanelPos = enum
  top
  bottom
  left
  right

type Indicator = enum
  none
  num
  numbers
  dots

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
  iconSize: int32 = 32
  pos: PanelPos = PanelPos.bottom
  color: string = "#070C1E"
  mouse_x: float
  mouse_y: float
  scrollUpCmd: string
  scrollDownCmd: string
  desktop_indicator: Indicator = Indicator.none

type WidgetType = enum
  favorite
  clock
  volume
  menu
  power
  desktop

type PanelItem = object
  widget: WidgetType
  icon: string
  exec: string
  terminal: bool

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

type imgProc = proc (curWS: string): Image

var leftItems: seq[PanelItem]
var rightItems: seq[PanelItem]
var widgets: seq[Widget] = @[]
var workspaces: seq[int] = @[]
var  displayInfo = DisplayInfo(name: "Unknown")
var p = LevePanel()
var newDesktopImg: imgProc
let opts = SubprocessOptions(useStdout: true)
let volProcess = startSubprocess("pactl", ["subscribe"], opts)
setCurrentDir(getHomeDir())

proc updateWidget(w: ptr Widget)
include "leve-panel"/[config, favorites, clock, volume, menu, power]
include "leve-panel"/[desktop_indicator, panel, output, callbacks]

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
  echo "Starting Leve-Panel...\n"

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
    echo "Error: Failed to get pointer"

  # Add pointer listener
  discard pointer.wl_pointer_add_listener(addr pointerListener, nil)

  # Commit surface
  p.surface.wl_surface_commit()

  # ----------------------------------------------------------------------------------------
  #                                  Setup FDs
  # ----------------------------------------------------------------------------------------

  # Get the Sway Socket Path
  let socketPath = getEnv("SWAYSOCK")
  if socketPath.len == 0:
    echo "Error: SWAYSOCK environment variable not set. Is Sway running?"

  # Create UNIX FD for sway
  let sway_fd = createNativeSocket(AF_UNIX, SOCK_STREAM, IPPROTO_NONE)
  if sway_fd == osInvalidSocket:
    echo "Error: Could not create socket file descriptor."
    quit(1)

  # Copy socketPath address to sockAddress var
  var sockAddress: Sockaddr_un
  sockAddress.sun_family = Domain.AF_UNIX.TSaFamily
  # Handle string bounds checking safely for the socket struct length
  let copyLen = min(socketPath.len, sockAddress.sun_path.high)
  copyMem(addr sockAddress.sun_path[0], addr socketPath[0], copyLen)

  # Connect FD to sockAddress
  if connect(sway_fd, cast[ptr SockAddr](addr sockAddress), SockLen(sizeof(sockAddress))) != 0:
    echo "Error: Failed to connect to SWAYSOCK."
    close(sway_fd)

  # Send the Subscription Payload
  let payload = """["workspace"]"""
  let packet = createIpcPacket(IpcTypeSubscribe, payload)
  
  let bytesSent = send(sway_fd, addr packet[0], packet.len.int32, 0'i32)
  if bytesSent < 0:
    echo "Error: Failed to send subscription payload."
    close(sway_fd)

  # Setup Timer FD
  let time_fd = timerfd_create(CLOCK_MONOTONIC, 0)
  var spec: Itimerspec
  #spec.it_interval.tv_sec = posix.Time(1) # Repeat every 1s
  spec.it_interval.tv_nsec = 100_000_000 # Repeat every 0.5s
  spec.it_value.tv_sec = posix.Time(1) # Start in 1s
  discard timerfd_settime(time_fd, 0, addr spec, nil)

  # Get Wayland FD
  let wl_fd = wl_display_get_fd(p.display)

  var fds: array[3, TPollfd]
  fds[0] = TPollfd(fd: wl_fd, events: POLLIN)
  fds[1] = TPollfd(fd: time_fd, events: POLLIN)
  fds[2] = TPollfd(fd: sway_fd.cint, events: POLLIN)

  #var buffer = newString(4096)
  var curWS = ""
  var swayEventsReady = false
  var lastSwayEvent = getMonoTime()
  var volPollTime = getMonoTime()

  echo "Leve-Panel: Clock Running..."

  # ----------------------------------------------------------------------------------------
  #                                  Event Loop
  # ----------------------------------------------------------------------------------------

  while true:
    echo "\n", "main loop"

    # Prepare Wayland
    while prepareRead(p.display) != 0:
      discard dispatchPending(p.display)
    discard wl_display_flush(p.display)

    # Poll FDs (timeout of -1 means block indefinitely)
    if poll(addr fds[0], 3, -1) < 0:
      break

    # Handle Wayland Events
    if (fds[0].revents and POLLIN) != 0:
      discard read_events(p.display)
      discard dispatchPending(p.display)
    else:
      cancel_read(p.display)

    # Clock widget
    if (fds[1].revents and POLLIN) != 0:
      var expirations: uint64
      discard read(time_fd, addr expirations, sizeof(expirations))

      echo "Tick: ", now().format("HH:mm:ss")

      # Update clock widget
      if now().second == 0:
        for widget in widgets:
          if widget.widgetType == WidgetType.clock:
            widget.img = newClockImg()
            updateWidget(addr widget)
        p.surface.wl_surface_commit()

    # Handle Sway IPC Events
    if (fds[2].revents and POLLIN) != 0:
      # Read the 14-Byte Response Header
      let headerBytes = readExact(sway_fd.cint, 14)

      # Verify magic string
      if headerBytes[0..5] != "i3-ipc":
        echo("Error: Invalid IPC magic string received.")
        #let bytesRead = recv(sway_fd, addr buffer[0], buffer.len.int32, 0'i32)
        #if bytesRead <= 0:
          #echo "Sway IPC disconnected or read error encountered."
      else:
        # Substring the buffer to isolate what arrived
        #let rawData = buffer[0 ..< bytesRead]
        #if rawData.len > 14:
          #echo "data > 14"
        #let jsonPayload = rawData[14 .. ^1]

        # Get payload length from bytes 6 to 9 (Little Endian)
        var replyLen: uint32
        copyMem(addr replyLen, addr headerBytes[6], 4)

        # Get message type from bytes 10 to 13
        var replyType: uint32
        copyMem(addr replyType, addr headerBytes[10], 4)

        # Read JSON Payload
        let json = readExact(cint(sway_fd), int(replyLen))
        curWS = getWsFromJson(json)
        echo "current ws: ", curWS
        swayEventsReady = true
        lastSwayEvent = getMonoTime()

    # Check if Sway Events are ready
    if swayEventsReady:
      let now = getMonoTime()
      let threshold = initDuration(milliseconds = 10)
      # Update desktop indicator widget
      if now > lastSwayEvent + threshold:
        for widget in widgets:
          if widget.widgetType == WidgetType.desktop:
            widget.img = newDesktopImg(curWS)
            updateWidget(addr widget)
        p.surface.wl_surface_commit()
        swayEventsReady = false

    # Volume widget
    if getMonoTime() > volPollTime + initDuration(milliseconds = 1000):
      if not volProcess.hasDataStdout():
        echo "outputPipe: no data"
      else:
        echo "Update volume state"
        # Update volume state
        cur_vol = getVolume()
        volMute = getMute()

        # Read all content to "clear" it from buffer
        discard volProcess.readStdout()

        # Check widget state
        if volState != getVolState():
          # Update widget
          volState = getVolState()
          for widget in widgets:
            if widget.widgetType == WidgetType.volume:
              widget.img = newVolImg()
              updateWidget(addr widget)
          p.surface.wl_surface_commit()

      volPollTime = getMonoTime()



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


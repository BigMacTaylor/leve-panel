# ========================================================================================
#
#                                   Leve Panel
#                                    Output
#
# ========================================================================================

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
  info.changed = true

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

  discard xdgOutput.zxdg_output_v1_add_listener(addr xdgOutputListener, cast[pointer](displayInfo))

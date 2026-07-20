# ========================================================================================
#
#                                   Leve Panel
#                                     Output
#
# ========================================================================================

proc xdgOutputLogicalSize(
    data: pointer, xdgOutput: ptr zxdgOutputV1, width: int32, height: int32
) {.cdecl.} =
  let info = cast[DisplayInfo](data)
  info.width = width
  info.height = height
  echo "[Output] \'", info.name, "\' Logical Size: ", width, "x", height

proc xdgOutputLogicalPos(
    data: pointer, xdgOutput: ptr zxdgOutputV1, width: int32, height: int32
) {.cdecl.} =
  let info = cast[DisplayInfo](data)
  info.pos_x = width
  info.pos_y = height
  echo "[Output] \'", info.name, "\' Logical Pos: ", width, "x", height

proc xdgOutputName(data: pointer, xdgOutput: ptr zxdgOutputV1, name: cstring) {.cdecl.} =
  let info = cast[DisplayInfo](data)
  info.name = $name
  echo "[Output] \'", info.name, "\' Discovered"

proc xdgOutputDescription(data: pointer, xdgOutput: ptr zxdgOutputV1, description: cstring) {.cdecl.} =
  let info = cast[DisplayInfo](data)
  echo "[Output] \'", info.name, "\' ", description

proc xdgOutputDone(data: pointer, xdgOutput: ptr zxdgOutputV1) {.cdecl.} =
  let info = cast[DisplayInfo](data)
  echo "[Output] \'", info.name, "\' Configuration finalized. \n"
  info.changed = true

# Initialize listeners
const xdgOutputListener =  zxdgOutputV1Listener(
  logical_size: xdgOutputLogicalSize,
  logical_position: xdgOutputLogicalPos,
  name: xdgOutputName,
  description: xdgOutputDescription,
  done: xdgOutputDone
)

proc bindOutput(manager: ptr zxdgOutputManagerV1, output: ptr wl_output) =
  # Create the XDG Output object for the given Wayland output
  let xdgOutput = manager.zxdg_output_manager_v1_get_xdg_output(output)
  if xdgOutput == nil:
    echo "Error: Failed to create XDG Output"
    return

  discard xdgOutput.zxdg_output_v1_add_listener(addr xdgOutputListener, cast[pointer](displayInfo))


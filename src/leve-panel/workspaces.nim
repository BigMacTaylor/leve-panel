# ========================================================================================
#
#                                   Leve Panel
#                                   Workspaces
#
# ========================================================================================

import std/[algorithm, strscans]

proc getCurrentWS(): int =
  for workspace in workspaces:
    if active in workspace.state:
      return workspace.num

proc getNumWorkspaces(): int =
  return workspaces.len

# Handle Workspace Events
proc onID(data: pointer; handle: ptr ext_workspace_handle_v1; id: cstring) {.cdecl.} =
  echo "[Workspace] ", $cast[uint](handle), " changed ID to: ", id

proc onWsNameChange(data: pointer; handle: ptr ext_workspace_handle_v1; name: cstring) {.cdecl.} =
  for ws in workspaces.mitems:
    if ws.handle == handle:
      let wsID = $cast[uint](handle)

      if scanf($name, "$i:$+", ws.num, ws.name):
        echo "[Workspace] ", wsID, " changed num to: ", ws.num
        echo "[Workspace] ", wsID, " changed name to \'", ws.name, "\'"
      elif scanf($name, "$i", ws.num):
        echo "[Workspace] ", wsID, " changed num to: ", ws.num
      else:
        echo "[Workspace] Error: Failed to parse name: ", $name

      workspaces.sort(proc (x, y: WorkspaceData): int = cmp(x.num, y.num))

      return

proc onCoord(data: pointer; handle: ptr ext_workspace_handle_v1; coordinates: ptr wl_array) {.cdecl.} =
  echo "[Workspace] ", $cast[uint](handle), " changed coords: "

proc onWsState(data: pointer; handle: ptr ext_workspace_handle_v1; state: uint32) {.cdecl.} =
  for ws in workspaces.mitems:
    if ws.handle == handle:
      echo "[Workspace] ", ws.name, " changed state to: ", state

      if state == 1:
        ws.state = ws.state + {active}
      else:
        ws.state.excl(active)
      return

proc onCap(data: pointer; handle: ptr ext_workspace_handle_v1; capabilities: uint32) {.cdecl.} =
  echo "[Workspace] ", $cast[uint](handle), " changed capabilities to: ", capabilities

proc onWsRemove(data: pointer; handle: ptr ext_workspace_handle_v1) {.cdecl.} =
  for i in 0 ..< workspaces.len:
    if workspaces[i].handle == handle:
      echo "[Workspace] ", workspaces[i].name, " destroyed by compositor."
      workspaces.delete(i)
      return

var workspaceListener = ext_workspace_handle_v1_listener(
  id: onID,
  name: onWsNameChange,
  coordinates: onCoord,
  state: onWsState,
  capabilities: onCap,
  removed: onWsRemove
)

proc newWorkspaceData(ws: ptr ext_workspace_handle_v1): WorkspaceData =
  result.handle = ws
  result.num = workspaces.len + 1
  result.name = $cast[uint](ws)

# Triggered when the manager broadcasts a new workspace group
proc onWsGroup(data: pointer, manager: ptr ext_workspace_manager_v1, id: ptr ext_workspace_group_handle_v1) {.cdecl.} =
  echo "[WS-Manager] New workspace group discovered: ", cast[uint](id)

# Handle workspace events
proc onWsEvent(data: pointer, manager: ptr ext_workspace_manager_v1, ws: ptr ext_workspace_handle_v1) {.cdecl.} =
  # Add ws handle to list of workspaces
  let wsData = newWorkspaceData(ws)
  workspaces.add(wsData)

  echo "[WS-Manager] New workspace discovered: ", $cast[uint](ws)

  discard ws.ext_workspace_handle_v1_add_listener(addr workspaceListener, data)

proc onWsEventDone(data: pointer, manager: ptr ext_workspace_manager_v1) {.cdecl.} =
  echo "[WS-Manager] Event finished by compositor. \n"

  # Update desktop widget
  for widget in widgets:
    if widget.widgetType == WidgetType.desktop:
      widget.img = newDesktopImg(getCurrentWS())
      updateWidget(addr widget)
  p.surface.wl_surface_commit()

# Triggered when the compositor destroys the manager instance
proc onManagerFinished(data: pointer, manager: ptr ext_workspace_manager_v1) {.cdecl.} =
  echo "[WS-Manager] Session finished by compositor."

# Statically assign callbacks to workspace manager
var managerListener = ext_workspace_manager_v1_listener(
  workspace_group: onWsGroup,
  workspace: onWsEvent,
  done: onWsEventDone,
  finished: onManagerFinished
)

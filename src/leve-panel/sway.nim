# ========================================================================================
#
#                                   Leve Panel
#                                   Sway Setup
#
# ========================================================================================

import std/[json, algorithm]

proc initWorkspaces() =
  let (output, exitCode) = execCmdEx("swaymsg -t get_workspaces")
  
  if exitCode != 0:
    echo "Error: Could not connect to sway"
    return

  let json = try:
    parseJson(output)
  except:
    echo "Error: Could not parse json"
    return

  for workspace in json:
    workspaces.add(parseInt(workspace["name"].getStr()))

# Helper to construct a raw Sway IPC message packet
proc createIpcPacket(msgType: uint32, payload: string): string =
# Package an IPC command with headers: Magic string, length, and type
  let len = payload.len.int32
  result = IPC_MAGIC & "\0\0\0\0" & "\x02\0\0\0" # 2 for subscribe
  # Replace \0\0\0\0 with our actual len (in little endian)
  result[6] = char(len and 0xFF)
  result[7] = char((len shr 8) and 0xFF)
  result[8] = char((len shr 16) and 0xFF)
  result[9] = char((len shr 24) and 0xFF)
  result.add(payload)

# Helper to read an exact amount of bytes from the socket
proc readExact(fd: cint, bytesToRead: int): string =
  result = newString(bytesToRead)
  var totalRead = 0
  while totalRead < bytesToRead:
    let chunk = read(fd, result[totalRead].addr, bytesToRead - totalRead)
    if chunk <= 0:
      echo("Error: Sway connection closed or failed while reading.")
      break
    totalRead += chunk

proc getSwayFD(): cint =
  # Get the Sway Socket Path
  let socketPath = getEnv("SWAYSOCK")
  if socketPath.len == 0:
    echo "Warning: SWAYSOCK environment variable not set. Is Sway running?"
    return -1

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
    return -1

  # Send the Subscription Payload
  let payload = """["workspace"]"""
  let packet = createIpcPacket(IpcTypeSubscribe, payload)
  
  let bytesSent = send(sway_fd, addr packet[0], packet.len.int32, 0'i32)
  if bytesSent < 0:
    echo "Error: Failed to send subscription payload."
    close(sway_fd)
    return -1

  # Get initial desktops
  initWorkspaces()

  return cint(sway_fd)

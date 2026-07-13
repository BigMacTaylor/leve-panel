# ========================================================================================
#
#                                   Leve Panel
#                                    Tooltip
#
# ========================================================================================

proc newTooltipImg(tooltip: ptr Tooltip): Image =
  echo "\nDrawing tooltip... "

  let width = tooltip.width
  let height = tooltip.height

  # Draw tooltip background
  var img = newImage(width, height)
  img.fill(rgba(40, 40, 40, 255)) # Dark gray

  # Draw text
  let text = tooltip.text
  let font = try:
    readFont(fontPath)
  except:
    fontPath = getFont()
    readFont(fontPath)
  font.size = 14
  font.paint.color = color(1, 1, 1) # White

  # Center text both horizontally and vertically
  let layout = font.typeset(
    text,
    bounds = vec2(img.width.float, img.height.float),
    hAlign = CenterAlign,  # Horizontal: Left, Center, Right
    vAlign = MiddleAlign   # Vertical: Top, Middle, Bottom
  )

  # Draw the text within the specified bounds, centered
  img.fillText(layout, translate(vec2(0, 0)))

  return img

proc updateTooltip(tooltip: ptr Tooltip) =
  let width = tooltip.width
  let height = tooltip.height

  # Draw tooltip
  let img = newTooltipImg(tooltip)

  # Copy new image to shared buffer
  copyMem(tooltip.pixelData, img.data[0].addr, tooltip.pixelDataSize)

  # Attach and Damage
  tooltip.surface.wl_surface_attach(tooltip.buffer, 0, 0)
  tooltip.surface.wl_surface_damage(0, 0, width, height)

proc createTooltip(w: Widget) =
  echo "create tooltip"
  tt.height = 30

  case w.widgetType
  of WidgetType.clock:
    tt.width = 150
    tt.text = getClockTT()
  of WidgetType.volume:
    tt.width = 100
    if volMute:
      tt.text = "Volume: Muted"
    else:
      tt.text = "Volume: " & $cur_vol & "%"
  else:
    return

  w.createPopup(addr tt)

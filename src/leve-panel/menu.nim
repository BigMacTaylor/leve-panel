# ========================================================================================
#
#                                   Leve Panel
#                                     Menu
#
# ========================================================================================

proc newMenuImg(menu: ptr Menu): Image =
  echo "\nDrawing menu... "

  let width = menu.width
  let height = menu.height

  # Draw tooltip background
  var img = newImage(width, height)
  img.fill(rgba(40, 40, 40, 255)) # Dark gray

  # Draw text
  let title = menu.text
  let body = "items"

  let text = title & "\n" & body

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

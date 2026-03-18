# ========================================================================================
#
#                                   Leve Panel
#                                   Favorites
#
# ========================================================================================

proc createBtn(fav: Favorite): Image =
  let padding = (p.size - p.iconSize) / 2

  # Create button
  let button = newImage(p.size, p.size)

  var icon: Image

  # Load Icon
  if fav.icon.endsWith(".png"):
    icon = readImage(fav.icon)

  elif fav.icon.endsWith(".svg"):
    echo "svg block"
    icon = readImage(fav.icon)

    #button.fill(rgba(255, 255, 255, 255))

    button.draw(
      icon,
      translate(vec2(100, 100)) *
      scale(vec2(0.2, 0.2)) *
      translate(vec2(-450, -450))
    )

  else:
    echo "Error: Icon not found"
    icon = newImage(p.size, p.size)

  # Resize Icon
  let sizedIcon = icon.resize(p.iconSize, p.iconSize)
  button.draw(sizedIcon, translate(vec2(padding.float32, padding.float32)))

  return button

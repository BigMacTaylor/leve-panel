# ========================================================================================
#
#                                   Leve Panel
#                                   Favorites
#
# ========================================================================================

proc createBtn(fav: Favorite): Image =
  let padding = (p.size - p.iconSize) / 2
  let iconPath = getConfigDir() / "icons" / "favorites"

  # Create button
  let button = newImage(p.size, p.size)

  var icon: Image

  # Load Icon
  echo iconPath / fav.icon
  if fav.icon.endsWith(".png"):
    echo "png found"
    icon = readImage(iconPath / fav.icon)

  # TODO fix svg support
  if fav.icon.endsWith(".svg"):
    echo "svg block"
    icon = readImage(iconPath / "folder.svg")

    #button.fill(rgba(255, 255, 255, 255))

    button.draw(
      icon,
      translate(vec2(100, 100)) *
      scale(vec2(0.2, 0.2)) *
      translate(vec2(-450, -450))
    )

  if icon.width > 0 and icon.height > 0:
    echo "icon"

  # Resize Icon
  let sizedIcon = icon.resize(p.iconSize, p.iconSize)
  button.draw(sizedIcon, translate(vec2(padding.float32, padding.float32)))


  return button

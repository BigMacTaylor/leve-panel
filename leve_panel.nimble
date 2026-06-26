# Package

version       = "1.0.7"
author        = "Mac Taylor"
description   = "Lightweight panel for Sway / Wayland."
license       = "GPL-3.0-only"
srcDir        = "src"
bin           = @["leve_panel=leve-panel"]

# Dependencies
requires "nim >= 2.2.4"
requires "https://github.com/nim-windowing/nayland.git"
requires "subprocess"
requires "parsetoml"
requires "pixie"

# Foreign Dependencies
foreignDeps  = @["pkg-config", "libwayland-dev", "pulseaudio-utils", "fontconfig"]

task install, "Custom install task":
  exec "nim c -d:release -d:strip --opt:speed --threads:off -o:bin/leve-panel src/leve_panel.nim"

# Package

version       = "1.0.3"
author        = "Mac Taylor"
description   = "Lightweight panel for Sway / Wayland."
license       = "GPL-3.0-only"
srcDir        = "src"
bin           = @["leve_panel"]


# Dependencies
requires "nim >= 2.2.4"
requires "https://github.com/BigMacTaylor/nayland.git"
requires "asynctools"
requires "parsetoml"
requires "pixie"

# Foreign Dependencies
foreignDeps  = @["pkg-config", "libwayland-dev", "pulseaudio-utils"]

task release, "Build release":
  exec "nim c -d:release -d:strip --opt:size --threads:off -o:bin/leve_panel src/leve_panel.nim"

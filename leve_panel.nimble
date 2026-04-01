# Package

version       = "1.0.2"
author        = "Mac Taylor"
description   = "Lightweight panel for Sway / Wayland."
license       = "GPL-3.0-only"
srcDir        = "src"
bin           = @["leve_panel"]


# Dependencies
requires "nim >= 2.2.4"
requires "https://github.com/nim-windowing/nayland.git"
requires "asynctools"
requires "parsetoml"
requires "pixie"

task release, "Build release":
  exec "nim c -d:release -d:strip --opt:size --threads:off -o:bin/leve_panel src/leve_panel.nim"

# Leve Panel

A very simple and lightweight panel for Wayland. It uses pure Wayland, without any heavy dependencies like Qt or GTK. It only needs `wlr-layer-shell` installed. So should work on any compositor that supports the `wlr-layer-shell-unstable-v1` protocol.

![leve_panel](https://github.com/BigMacTaylor/leve-panel/blob/main/screenshots/leve_panel.png "Leve Panel")

## Installation

### Debian/Ubuntu

Download the `.deb` file from the [releases page](https://github.com/BigMacTaylor/leve-panel/releases) and

```bash
sudo apt install ./leve-panel_*.deb
```

### Fedora

Download the `.rpm` file from the [releases page](https://github.com/BigMacTaylor/leve-panel/releases) and

```bash
sudo dnf install ./leve-panel*.rpm
```

## Dependencies

- libwayland-dev
- pulseaudio-utils
- fontconfig

## Running

To manually start leve-panel just enter the `leve-panel` command.
Or automatically start it, by adding it to your sway/startup config like this:

```text
exec_always {
    killall leve-panel
    leve-panel
}
```

## Customization

![leve_panel](https://github.com/BigMacTaylor/leve-panel/blob/main/screenshots/leve_panel_1.png "Leve Panel")

![leve_panel](https://github.com/BigMacTaylor/leve-panel/blob/main/screenshots/leve_panel_3.png "Leve Panel")

![leve_panel](https://github.com/BigMacTaylor/leve-panel/blob/main/screenshots/leve_panel_2.png "Leve Panel")

Config file is located in `~/.config/leve-panel/` and is in TOML format. Leve-panel must be restarted for changes to take effect.

Favorite icons should be placed in `~/.config/leve-panel/icons/` .

*NOTE: Currently only png icons are supported, because pixie svg support is incomplete.*

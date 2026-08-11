# Leve Panel

A very simple, and ultra lightweight panel for Wayland. It uses pure Wayland, without any heavy dependencies like Qt or GTK.
So should work on any compositor that supports the `wlr-layer-shell-unstable-v1` protocol. So far its been tested on Sway, Labwc, and Niri.

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

To start leve-panel manually, just enter the `leve-panel` command.
Or, to start it automatically, add it to your sway/startup config like:

```text
exec_always {
    killall leve-panel
    leve-panel
}
```

## Customization

The config file is located in `~/.config/leve-panel/` and is in TOML format.

You can run multiple instances of leve-panel by specifying the config file.

```text
leve-panel -c top_panel.toml
leve-panel -c bottom_panel.toml
```

Leve-panel must be restarted before changes to the config take effect.

Favorite icons should be placed in `~/.config/leve-panel/icons/` .

*NOTE: Currently only png icons are supported, because pixie svg support is incomplete.*

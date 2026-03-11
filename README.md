# Flare

A programmable visual attention system for macOS. Flashes the edges of your screen so you stop ignoring notifications.

Built on [Hammerspoon](https://www.hammerspoon.org/).

## Why

Human vision is optimized for motion at the periphery. Notifications sit in the center where we've trained ourselves to ignore them. Flare exploits the one part of the brain you can't mute.

## Install

### Prerequisites

```sh
brew install --cask hammerspoon
```

Enable the CLI tool in Hammerspoon > Preferences > Enable CLI.

### Setup

```sh
git clone https://github.com/counterbeing/flare.git
cd flare
./install/install.sh
```

This symlinks the Lua module into `~/.hammerspoon/flare/`, adds `require("flare")` to your Hammerspoon config, and links the `flare` CLI to `/usr/local/bin`.

Reload Hammerspoon to activate.

## Usage

### CLI

```sh
flare alert                         # red edge flash
flare success                       # green edge flash
flare error                         # red flash, 3 pulses
flare pulse                         # blue flash, 3 pulses
flare custom '#FF8800'              # custom color
flare custom '#FF8800' --pulses 3   # custom with options
```

### HTTP

Flare runs an HTTP server on `localhost:5050`.

```sh
# trigger a preset
curl -X POST http://localhost:5050/trigger \
  -H "Content-Type: application/json" \
  -d '{"preset":"alert"}'

# custom trigger
curl -X POST http://localhost:5050/trigger \
  -H "Content-Type: application/json" \
  -d '{"color":"#FF8800","pulses":2,"duration":0.3}'

# health check
curl http://localhost:5050/health
```

### From Hammerspoon

```lua
local flare = require("flare")
flare.trigger("alert")
flare.trigger("custom", { color = "#FF8800", pulses = 2 })
```

## Configuration

Create `~/.flare/config.lua`:

```lua
return {
  thickness = 8,
  duration = 0.3,
  pulses = 1,
  interval = 0.15,
  sound = true,
  notify = false,
  httpPort = 5050,
  presets = {
    alert = { color = { red = 1, green = 0.5, blue = 0, alpha = 1 } },
  }
}
```

## Presets

| Name    | Color | Pulses |
|---------|-------|--------|
| alert   | Red   | 1      |
| success | Green | 1      |
| error   | Red   | 3      |
| pulse   | Blue  | 3      |

## Use Cases

- Agent needs input: `flare alert`
- Build finished: `flare success` / `flare error`
- Remote trigger from another machine: `curl http://workstation:5050/trigger -d '{"preset":"alert"}'`

## License

MIT

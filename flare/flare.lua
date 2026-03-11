local animations = require("flare.animations")

local M = {}

M.config = {
  thickness = 24,
  duration = 0.8,
  pulses = 1,
  interval = 0.08,
  sound = false,
  notify = false,
  httpPort = 5050,
}

-- Each preset defines a 3-color surge: warmup → main → hot
-- Colors should be visually distinct from each other
M.presets = {
  alert = {
    duration = 1.0, thickness = 28,
    colors = {
      { red = 1,   green = 0.4, blue = 0,   alpha = 0.7 },   -- amber warmup
      { red = 1,   green = 0.1, blue = 0.1, alpha = 0.9 },   -- red main
      { red = 1,   green = 0.9, blue = 0.9, alpha = 1.0 },   -- hot white-pink
    },
  },
  success = {
    duration = 0.9, thickness = 24,
    colors = {
      { red = 0,   green = 0.5, blue = 0.3, alpha = 0.6 },   -- teal warmup
      { red = 0.1, green = 0.9, blue = 0.3, alpha = 0.9 },   -- bright green main
      { red = 0.7, green = 1,   blue = 0.8, alpha = 1.0 },   -- minty white hot
    },
  },
  error = {
    duration = 0.8, thickness = 28, pulses = 3,
    colors = {
      { red = 0.8, green = 0,   blue = 0.4, alpha = 0.7 },   -- magenta warmup
      { red = 1,   green = 0,   blue = 0,   alpha = 0.95 },   -- pure red main
      { red = 1,   green = 0.6, blue = 0,   alpha = 1.0 },   -- orange-fire hot
    },
  },
  pulse = {
    duration = 0.7, thickness = 24, pulses = 3,
    colors = {
      { red = 0.3, green = 0,   blue = 0.7, alpha = 0.6 },   -- purple warmup
      { red = 0.2, green = 0.3, blue = 1,   alpha = 0.9 },   -- electric blue main
      { red = 0.6, green = 0.8, blue = 1,   alpha = 1.0 },   -- ice-white hot
    },
  },
}

function M.hexToColor(hex)
  hex = hex:gsub("^#", "")
  if #hex ~= 6 then return nil end
  local r = tonumber(hex:sub(1, 2), 16)
  local g = tonumber(hex:sub(3, 4), 16)
  local b = tonumber(hex:sub(5, 6), 16)
  if not (r and g and b) then return nil end
  return { red = r / 255, green = g / 255, blue = b / 255, alpha = 0.85 }
end

function M.loadConfig()
  local path = os.getenv("HOME") .. "/.flare/config.lua"
  local ok, userCfg = pcall(dofile, path)
  if ok and type(userCfg) == "table" then
    for k, v in pairs(userCfg) do
      if k == "presets" and type(v) == "table" then
        for name, preset in pairs(v) do
          M.presets[name] = preset
        end
      else
        M.config[k] = v
      end
    end
  end
end

function M.trigger(name, overrides)
  overrides = overrides or {}

  local opts = {}
  for k, v in pairs(M.config) do opts[k] = v end

  local preset = M.presets[name]
  if preset then
    for k, v in pairs(preset) do opts[k] = v end
  end

  for k, v in pairs(overrides) do
    if k == "color" and type(v) == "string" then
      opts.color = M.hexToColor(v)
    else
      opts[k] = v
    end
  end

  if opts.pulses and opts.pulses > 1 then
    animations.pulse(opts)
  else
    animations.flash(opts)
  end

  if opts.sound then
    local s = hs.sound.getByName("Ping")
    if s then s:play() end
  end

  if opts.notify then
    hs.notify.new({ title = "Flare", informativeText = name }):send()
  end
end

function M.nag(name, overrides)
  overrides = overrides or {}

  local opts = {}
  for k, v in pairs(M.config) do opts[k] = v end

  local preset = M.presets[name]
  if preset then
    for k, v in pairs(preset) do opts[k] = v end
  end

  for k, v in pairs(overrides) do
    if k == "color" and type(v) == "string" then
      opts.color = M.hexToColor(v)
    else
      opts[k] = v
    end
  end

  animations.nag(opts)
end

function M.stop()
  animations.stopNag()
end

return M

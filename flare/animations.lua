local M = {}

local activeCanvases = {}
local activeTimers = {}

local GLOW_LAYERS = 8
local FADE_FPS = 30

function M.cleanup()
  for _, t in ipairs(activeTimers) do
    pcall(function() t:stop() end)
  end
  activeTimers = {}
  for _, c in ipairs(activeCanvases) do
    pcall(function() c:delete() end)
  end
  activeCanvases = {}
end

local function trackTimer(timer)
  activeTimers[#activeTimers + 1] = timer
  return timer
end

local function lerpColor(a, b, t)
  return {
    red   = a.red   + (b.red   - a.red)   * t,
    green = a.green + (b.green - a.green) * t,
    blue  = a.blue  + (b.blue  - a.blue)  * t,
    alpha = a.alpha + (b.alpha - a.alpha) * t,
  }
end

-- Build glow elements for one edge canvas
local function buildGlowElements(color, edgeW, edgeH, dir, layers)
  local elements = {}
  for i = 1, layers do
    local frac = (i - 1) / layers
    local alpha = color.alpha * (1 - frac * 0.9)
    local layerSize = math.floor((dir == "down" or dir == "up") and edgeH / layers or edgeW / layers)
    local offset = (i - 1) * layerSize

    local rect
    if dir == "down" then
      rect = { x = 0, y = offset, w = edgeW, h = layerSize }
    elseif dir == "up" then
      rect = { x = 0, y = edgeH - offset - layerSize, w = edgeW, h = layerSize }
    elseif dir == "right" then
      rect = { x = offset, y = 0, w = layerSize, h = edgeH }
    else
      rect = { x = edgeW - offset - layerSize, y = 0, w = layerSize, h = edgeH }
    end

    elements[#elements + 1] = {
      type = "rectangle",
      action = "fill",
      fillColor = { red = color.red, green = color.green, blue = color.blue, alpha = alpha },
      frame = rect,
    }
  end
  return elements
end

-- Create edge canvases at a given thickness
local function createEdges(screen, color, thickness)
  local f = screen:fullFrame()
  local canvases = {}
  local edges = {
    { x = f.x, y = f.y, w = f.w, h = thickness, dir = "down" },
    { x = f.x, y = f.y + f.h - thickness, w = f.w, h = thickness, dir = "up" },
    { x = f.x, y = f.y, w = thickness, h = f.h, dir = "right" },
    { x = f.x + f.w - thickness, y = f.y, w = thickness, h = f.h, dir = "left" },
  }

  for _, edge in ipairs(edges) do
    local c = hs.canvas.new({ x = edge.x, y = edge.y, w = edge.w, h = edge.h })
    local elems = buildGlowElements(color, edge.w, edge.h, edge.dir, GLOW_LAYERS)
    for _, e in ipairs(elems) do c:appendElements(e) end
    c:level(hs.canvas.windowLevels.overlay)
    c:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.stationary)
    c:alpha(0)
    c:show()
    canvases[#canvases + 1] = c
    activeCanvases[#activeCanvases + 1] = c
  end

  return canvases
end

local function setAlpha(canvases, alpha)
  for _, c in ipairs(canvases) do
    pcall(function() c:alpha(alpha) end)
  end
end

local function deleteCanvases(canvases)
  for _, c in ipairs(canvases) do
    pcall(function() c:delete() end)
  end
  local remaining = {}
  for _, ac in ipairs(activeCanvases) do
    local found = false
    for _, c in ipairs(canvases) do
      if ac == c then found = true; break end
    end
    if not found then remaining[#remaining + 1] = ac end
  end
  activeCanvases = remaining
end

-- Animate alpha over duration. `from` → `to`.
local function animateAlpha(canvases, from, to, duration, callback)
  if duration <= 0 then
    setAlpha(canvases, to)
    if callback then callback() end
    return
  end
  local steps = math.max(math.floor(duration * FADE_FPS), 1)
  local step = 0
  local interval = duration / steps
  setAlpha(canvases, from)

  local timer
  timer = hs.timer.doEvery(interval, function()
    step = step + 1
    local t = step / steps
    if t > 1 then t = 1 end
    setAlpha(canvases, from + (to - from) * t)
    if step >= steps then
      timer:stop()
      if callback then callback() end
    end
  end)
  trackTimer(timer)
end

-- Run a multi-phase color surge across all screens.
-- Each phase: new color, growing thickness, crossfade from previous.
-- phases: list of { color, thickness, duration }
local function surge(screens, phases, callback)
  local phaseIndex = 0
  local prevCanvases = nil

  local function nextPhase()
    phaseIndex = phaseIndex + 1
    if phaseIndex > #phases then
      -- Final fade out of the last layer
      if prevCanvases then
        animateAlpha(prevCanvases, 1, 0, 0.3, function()
          deleteCanvases(prevCanvases)
          if callback then callback() end
        end)
      else
        if callback then callback() end
      end
      return
    end

    local phase = phases[phaseIndex]
    local dur = phase.duration

    -- Create new layer
    local newCanvases = {}
    for _, screen in ipairs(screens) do
      local c = createEdges(screen, phase.color, phase.thickness)
      for _, cv in ipairs(c) do newCanvases[#newCanvases + 1] = cv end
    end

    -- Crossfade: fade in new while fading out old
    local fadeInTime = dur * 0.4
    local holdTime = dur * 0.35
    local rampTime = dur * 0.25

    -- Fade in the new layer
    animateAlpha(newCanvases, 0, 1, fadeInTime)

    -- Fade out the old layer simultaneously
    if prevCanvases then
      local old = prevCanvases
      animateAlpha(old, 1, 0, fadeInTime * 0.8, function()
        deleteCanvases(old)
      end)
    end

    -- After fade-in, hold at full brightness, then move to next phase
    trackTimer(hs.timer.doAfter(fadeInTime + holdTime, function()
      prevCanvases = newCanvases
      nextPhase()
    end))
  end

  nextPhase()
end

-- Build phases from opts.colors (array of 3 colors) or fall back to single color
local function buildPhases(opts)
  local thickness = opts.thickness or 24
  local duration = opts.duration or 0.8
  local colors = opts.colors

  if colors and #colors >= 3 then
    return {
      { color = colors[1], thickness = math.floor(thickness * 0.5),  duration = duration * 0.3 },
      { color = colors[2], thickness = thickness,                     duration = duration * 0.35 },
      { color = colors[3], thickness = math.floor(thickness * 1.6),   duration = duration * 0.35 },
    }
  end

  -- Fallback for single color (custom triggers)
  local base = opts.color or { red = 1, green = 0, blue = 0, alpha = 0.85 }
  local dim = { red = base.red * 0.5, green = base.green * 0.5, blue = base.blue * 0.5, alpha = base.alpha * 0.6 }
  local hot = lerpColor(base, { red = 1, green = 1, blue = 1, alpha = 1 }, 0.4)
  return {
    { color = dim,  thickness = math.floor(thickness * 0.5),  duration = duration * 0.3 },
    { color = base, thickness = thickness,                     duration = duration * 0.35 },
    { color = hot,  thickness = math.floor(thickness * 1.6),   duration = duration * 0.35 },
  }
end

function M.flash(opts)
  M.cleanup()
  local screens = hs.screen.allScreens()
  local phases = opts.phases or buildPhases(opts)
  surge(screens, phases)
end

function M.pulse(opts)
  M.cleanup()

  local thickness = opts.thickness or 24
  local duration = opts.duration or 0.7
  local pulseCount = opts.pulses or 3
  local interval = opts.interval or 0.08
  local screens = hs.screen.allScreens()

  local basePhases = buildPhases(opts)

  local count = 0
  local function doPulse()
    count = count + 1
    local scale = 0.7 + (count / pulseCount) * 0.5

    local phases = {}
    for i, bp in ipairs(basePhases) do
      phases[i] = {
        color = bp.color,
        thickness = math.floor(bp.thickness * scale),
        duration = bp.duration,
      }
    end

    surge(screens, phases, function()
      if count < pulseCount then
        trackTimer(hs.timer.doAfter(interval, doPulse))
      end
    end)
  end

  doPulse()
end

-- Repeating nag mode: keeps firing surges until user interacts or timeout
local nagEventTap = nil
local nagTimer = nil
local nagTimeoutTimer = nil

local function stopNag()
  if nagEventTap then
    pcall(function() nagEventTap:stop() end)
    nagEventTap = nil
  end
  if nagTimer then
    pcall(function() nagTimer:stop() end)
    nagTimer = nil
  end
  if nagTimeoutTimer then
    pcall(function() nagTimeoutTimer:stop() end)
    nagTimeoutTimer = nil
  end
  M.cleanup()
end

function M.nag(opts)
  -- Stop any existing nag first
  stopNag()

  local timeout = opts.timeout or 300  -- 5 minutes default
  local pauseBetween = opts.pauseBetween or 4  -- seconds between surges
  local screens = hs.screen.allScreens()
  local basePhases = buildPhases(opts)

  -- Watch for any keyboard or mouse event to cancel
  nagEventTap = hs.eventtap.new({
    hs.eventtap.event.types.keyDown,
    hs.eventtap.event.types.leftMouseDown,
    hs.eventtap.event.types.rightMouseDown,
    hs.eventtap.event.types.scrollWheel,
  }, function()
    stopNag()
    return false  -- pass the event through
  end)
  nagEventTap:start()

  -- Timeout after max duration
  nagTimeoutTimer = hs.timer.doAfter(timeout, function()
    stopNag()
  end)
  trackTimer(nagTimeoutTimer)

  -- Fire surges in a loop
  local function doNagSurge()
    if not nagEventTap then return end  -- stopped
    surge(screens, basePhases, function()
      if nagEventTap then
        nagTimer = hs.timer.doAfter(pauseBetween, doNagSurge)
        trackTimer(nagTimer)
      end
    end)
  end

  doNagSurge()
end

M.stopNag = stopNag

return M

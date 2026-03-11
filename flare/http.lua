local flare = require("flare.flare")

local M = {}
local server = nil

function M.start(port)
  port = port or flare.config.httpPort or 5050

  server = hs.httpserver.new(false, false)
  server:setPort(port)
  server:setCallback(function(method, path, headers, body)
    local responseHeaders = { ["Content-Type"] = "application/json" }

    if method == "GET" and path == "/health" then
      return '{"status":"ok"}', 200, responseHeaders
    end

    if method == "POST" and path == "/trigger" then
      local ok, data = pcall(hs.json.decode, body)
      if not ok or type(data) ~= "table" then
        return '{"error":"invalid json"}', 400, responseHeaders
      end

      local preset = data.preset or "custom"
      local overrides = {}
      if data.color then overrides.color = data.color end
      if data.pulses then overrides.pulses = data.pulses end
      if data.duration then overrides.duration = data.duration end
      if data.thickness then overrides.thickness = data.thickness end

      flare.trigger(preset, overrides)
      return '{"result":"triggered"}', 200, responseHeaders
    end

    if method == "POST" and path == "/nag" then
      local ok, data = pcall(hs.json.decode, body)
      if not ok or type(data) ~= "table" then
        return '{"error":"invalid json"}', 400, responseHeaders
      end
      local preset = data.preset or "alert"
      flare.nag(preset, data)
      return '{"result":"nagging"}', 200, responseHeaders
    end

    if method == "POST" and path == "/stop" then
      flare.stop()
      return '{"result":"stopped"}', 200, responseHeaders
    end

    return '{"error":"not found"}', 404, responseHeaders
  end)
  server:setName("Flare")

  local ok, err = pcall(function() server:start() end)
  if not ok then
    hs.logger.new("flare"):e("Failed to start HTTP server: " .. tostring(err))
  end
end

function M.stop()
  if server then
    server:stop()
    server = nil
  end
end

return M

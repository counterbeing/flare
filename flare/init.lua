local flare = require("flare.flare")
local http = require("flare.http")

flare.loadConfig()
http.start()

return flare

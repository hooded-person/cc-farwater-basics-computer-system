package.path = package.path..";/lib/?;/lib/?.lua;/lib/?/init.lua"
local config_path = "config.lon"

if not fs.exists(config_path) then
    error(("Configuration file '%s' does not exist."):format(config_path)) -- log:fatal as fuck lmao
end

local config = require("config.load")(config_path)

-- is niet echt nuttig eigenlijk, vooral gewoon een zeik ding dat zorgt dat hij crashed als een peripheral niet bij startup all is geladen
-- local valid = require("config.validate")(config)
-- if not valid then
--     error("Configuration file invalid")
-- end

return config
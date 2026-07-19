package.path = package.path .. ";/lib/?.lua;/lib/?/init.lua"
local config = require "config"

while true do
    shell.run("/bin/defrag.lua")
    print(("Running defrag every %d minutes"):format(config.data.run_defrag.interval))
    sleep(config.data.run_defrag.interval * 60)
end

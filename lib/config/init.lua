package.path = package.path..";/lib/?;/lib/?.lua;/lib/?/init.lua"
local h = fs.open("main_drive.peripheral", "r")
local main_drive = h.readAll()
h.close()

local config_file = "config.lon"

local config_path = nil

if not disk.hasData(main_drive) then
    if fs.exists(config_file) then
        term.setTextColor(colors.red)
        print(("Main drive '%s' contains no disk, configuration can not be accessed. Trying local copy"):format(
        main_drive))                                                                                                         -- log:errors
        config_path = config_file
        term.setTextColor(colors.white)
    else
        error(("Main drive '%s' contains no disk, configuration can not be accessed."):format(main_drive)) -- log:fatal as fuck lmao
    end
end

local mount = disk.getMountPath(main_drive)
if mount then
    config_path = fs.combine(mount, config_file)
end

local config = require("config.load")(config_path)

-- is niet echt nuttig eigenlijk, vooral gewoon een zeik ding dat zorgt dat hij crashed als een peripheral niet bij startup all is geladen
-- local valid = require("config.validate")(config)
-- if not valid then
--     error("Configuration file invalid")
-- end

if config.peripherals.main.drive_main ~= main_drive and config.auto_migrate then
    print(("Local main drive '%s' does not match config main drive '%s': updating local main drive"):format(
        main_drive, config.peripherals.main.drive_main)) -- log:info
    local h = fs.open("main_drive.peripheral", "w")
    h.write(config.peripherals.main.drive_main)
    h.close()
end

return config

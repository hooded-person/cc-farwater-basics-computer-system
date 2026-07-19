package.path = package.path .. ";/lib/?.lua;/lib/?/init.lua"
local config = require "config.local"
local main_drive = config.peripherals.main.drive_main

if not disk.hasData(main_drive) then
    term.setTextColor(colors.red)
    print("Main drive '%s' contains no disk, configuration can not be made accessible to other computer in the network")
    term.setTextColor(colors.white)
end

local mount = disk.getMountPath(main_drive)

local exists_handle_method = config.exists_handle_method

local files = {
    "/config.lon"
}

if exists_handle_method ~= "overwrite" and exists_handle_method ~= "skip" then
    term.setTextColor(colors.red)
    print(("Invalid File Exists Handle Method '%s', must be 'overwrite' or 'skip'"))
    term.setTextColor(colors.white)
    return
end

function copyFile(source, destination)
    print(("Copying '%s' to '%s'"):format(source, destination))

    if not fs.exists(source) then
        term.setTextColor(colors.red)
        print(("Source '%s' does not exists"):format(source))
        term.setTextColor(colors.white)
        
        return false
    end
    if fs.exists(destination) then
        if exists_handle_method == "skip" then
            term.setTextColor(colors.orange)
            print(("File '%s' already exists, skipping"):format(destination))
            term.setTextColor(colors.white)

            return false
        elseif exists_handle_method == "overwrite" then
            term.setTextColor(colors.orange)
            print(("File '%s' already exists, overwriting"):format(destination))
            term.setTextColor(colors.white)

            fs.delete(destination)
        end
    end

    fs.copy(source, destination)

    return true
end

for source, destination in pairs(files) do
    if type(source) == "number" then
        source = destination
    end

    local non_root_destination = destination:sub(1, 1) == "/" and destination:sub(2) or destination
    local destination_path = fs.combine(mount, non_root_destination)
    if destination_path:sub(1, #mount) ~= mount then
        term.setTextColor(colors.red)
        print(("Path error, destination '%s' is not in mounted drive '%s'"):format(destination_path, mount))
        term.setTextColor(colors.white)
    else
        copyFile(source, destination_path)
    end
end

local modem = peripheral.find("modem")
modem.transmit(config.channels.control, config.channels.control, 0) -- signals reboot
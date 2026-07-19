package.path = package.path .. ";/lib/?.lua;/lib/?/init.lua"
local config = require "config.local"
local main_drive = config.peripherals.main.drive_main

if not disk.hasData(main_drive) then
    term.setTextColor(colors.red)
    print("Main drive '%s' contains no disk, code can not be synced to disk")
    term.setTextColor(colors.white)
end

local mount = disk.getMountPath(main_drive)

local exists_handle_method = config.exists_handle_method

local sync_paths = {
    "/bin",
    "/lib",
    "/daemon.lua"
}
local exclude = {
    "/lib/config/local.lua",
    "/lib/telem",
    -- following are installed from http, cause limited disk space hihihihih.... why did i decide to sync libs using a disk... sigh
    "/lib/ecnet2",
    "/lib/ccryptolib",
    "/lib/taskmaster.lua"
}
local sync_to = "/" .. fs.combine(mount, "local")

function addExclude(path)
    exclude[path] = true
    if fs.isDir(path) then
        print(("Excluding directory '%s'"):format(path))
        local items = fs.list(path)
        for _, subItem in ipairs(items) do
            local subPath = "/" .. fs.combine(path, subItem)
            addExclude(subPath)
        end
    else
        print(("Excluding file '%s'"):format(path))
    end
end

for _, excluded in ipairs(exclude) do
    addExclude(excluded)
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

function syncDir(source_dir)
    local files = fs.list(source_dir)
    for _, file in ipairs(files) do
        local source = "/" .. fs.combine(source_dir, file)
        if fs.isDir(source) then
            syncDir(source)
        else
            local destination_path = "/" .. fs.combine(sync_to, source_dir, file)
            if destination_path:sub(1, #sync_to) ~= sync_to then
                term.setTextColor(colors.red)
                print(("Path error, destination '%s' is not in sync target '%s'"):format(destination_path, sync_to))
                term.setTextColor(colors.white)
            elseif not exclude[source] then
                copyFile(source, destination_path)
            end
        end
    end
end

function syncPath(path)
    if exclude[path] then
        return
    end

    if fs.isDir(path) then
        local contents = fs.list(path)
        for _, item in ipairs(contents) do
            local item_path = "/" .. fs.combine(path, item)
            syncPath(item_path)
        end
    else
        local destination_path = "/" .. fs.combine(sync_to, path)
        if destination_path:sub(1, #sync_to) ~= sync_to then
            term.setTextColor(colors.red)
            print(("Path error, destination '%s' is not in sync target '%s'"):format(destination_path, sync_to))
            term.setTextColor(colors.white)
        else
            copyFile(path, destination_path)
        end
    end
end

for _, path in ipairs(sync_paths) do
    syncPath(path)
end

local modem = peripheral.find("modem")
modem.transmit(config.channels.control, config.channels.control, 0) -- signals reboot

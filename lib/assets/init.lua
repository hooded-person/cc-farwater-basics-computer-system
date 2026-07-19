package.path = package.path .. ";/lib/?.lua;/lib/?/init.lua"
local config = require "config.local"

local assets = {
    __compact = true,
    loaders = {},
    savers = {},
}

-- reserved for internal use, when I want to split it over files
function import(tab)
    for name, func in pairs(tab.loaders) do
        assets.loaders[name] = func
    end
    for name, func in pairs(tab.savers) do
        assets.savers[name] = func
    end
end

function assets.getAssetDir(sub_dir)
    local assets_drive = config.peripherals.main.drive_assets

    if not disk.hasData(assets_drive) then
        term.setTextColor(colors.red)
        print("Assets drive '%s' contains no disk, can not access assets")
        term.setTextColor(colors.white)
        return nil
    end

    local mount = disk.getMountPath(assets_drive)

    local assets_dir = "/" .. fs.combine(mount)

    if sub_dir ~= nil then
        return "/" .. fs.combine(assets_dir, sub_dir)
    end

    return assets_dir
end

function assets.getFilename(path)
    local name = fs.getName(path)
    local extentionStart = name:find(".[^.]+$")
    return name:sub(1, extentionStart - 1)
end

-- Namespace utils
function assets.loadNamespaced(dir, loader, allowFiles)
    local contents = {}
    local namespaces = fs.list(dir)
    for _, itemName in ipairs(namespaces) do
        namespace = assets.getFilename(itemName) -- remove file extention for when `allowFiles=true`, other whise has no effect
        local path = "/" .. fs.combine(dir, itemName)
        if allowFiles or fs.isDir(path) then
            local parsed = loader(path)
            for k, v in pairs(parsed) do
                contents[namespace .. ":" .. k] = v
            end
        end
    end
    return contents
end

function assets.saveNamespaced(dir, saver, data)
    local contents = {}
    for k, v in pairs(data) do
        local namespace = k:match("^[^:]+")
        local name = k:match("[^:]+$")
        if contents[namespace] == nil then
            contents[namespace] = {}
        end
        contents[namespace][name] = v
    end
    for namespace, namespace_data in pairs(contents) do
        local namespace_dir = "/" .. fs.combine(dir, namespace)
        saver(namespace_dir, namespace_data)
    end
end

--[[ Basic loader and saver
/
  minecraft/
    potion.lon
    splash_potion.lon
]]
function assets.loaders.basic(dir)
    local loaded_assets = {}
    local files = fs.list(dir)
    for _, file in ipairs(files) do
        local path = "/" .. fs.combine(dir, file)
        if fs.isDir(path) then
            term.setTextColor(colors.orange)
            print(
                "WARNING: assets.loaders.basic loads recursivly, but assets.savers.basic can not save recursivly. Directory structure will be flattened")
            term.setTextColor(colors.white)
            loaded_assets[assets.getFilename(file)] = assets.loaders.basic(path)
        else
            local h = fs.open(path, "r")
            local data = h.readAll()
            h.close()
            loaded_assets[assets.getFilename(file)] = textutils.unserialise(data)
        end
    end
    return loaded_assets
end

function assets.savers.basic(dir, data)
    for asset_name, v in pairs(data) do
        local path = "/" .. fs.combine(dir, asset_name) .. ".lon"

        local serialised = textutils.serialise(v, {
            compact = assets.__compact
        })

        local h = fs.open(path, "w")
        h.write(serialised)
        h.close()
    end
end

--[[ Loader and saver for depthless. Requires `allowFiles = true` for `assets.loadNamespaced`
/
  minecraft.lon
]]
function assets.loaders.singular(dir)
    local path = "/" .. fs.combine(dir)
    if path:sub(#path - 3) ~= ".lon" then
        path = path .. ".lon"
    end

    local h = fs.open(path, "r")
    local serialised = h.readAll()
    h.close()

    local data = textutils.unserialise(serialised)

    return data
end

function assets.savers.singular(dir, data)
    local path = "/" .. fs.combine(dir) .. ".lon"

    local serialised = textutils.serialise(data, {
        compact = assets.__compact
    })

    local h = fs.open(path, "w")
    h.write(serialised)
    h.close()
end

return assets

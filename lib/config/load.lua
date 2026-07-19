function loadDynamic(config, part, path)
    if type(part) == "table" then
        for k, v in pairs(part) do
            local subpath = path == nil and k or path .. "." .. k
            part[k] = loadDynamic(config, v, subpath)
        end
    elseif type(part) == "string" and part:find("%$") then
        local dynamicChunk = "return " .. part:gsub("%$", "dollar")
        local func, err = load(dynamicChunk, part, "t", { 
            dollar = setmetatable({}, { __index = config }) -- prevent modifications
            })
        if func == nil or err ~= nil then
            error(("An error occured while loading dynamic config value at '%s': %s"):format(path, err))
        end
        local ok, res = pcall(func)
        if not ok or res == nil then
            error(("An error occured while loading dynamic config value at '%s': %s"):format(path, res ~= nil and res or "Dynamic chunk returned nil"))
        end
        return res
    end
    return part
end

return function(config_path)
    if not fs.exists(config_path) then
        error(("No configuration file present at '%s'."):format(config_path)) -- log:fatal
    end

    -- print(("Loading configuration file at '%s'"):format(config_path)) -- log:debug

    -- local func, err = loadfile(config_path, "t", {})
    -- if func == nil or err ~= nil then
    --     error(("Error while loading configuration file: %s"):format(err)) -- log:fatal
    -- end

    -- local ok, config = pcall(func)
    -- if not ok then
    --     error(("Error while running configuration file: %s"):format(config)) -- log:fatal
    -- end

    local h = fs.open(config_path, "r")
    local contents = h.readAll()
    h.close()

    local config = textutils.unserialise(contents)
    if config == nil then
        error("Error while loading configuration file") -- log:fatal
    end

    if type(config) ~= "table" then
        error(("Configuration file returned %s, expected table"):format(err)) -- log:fatal
    end

    config = loadDynamic(config, config)

    return config
end

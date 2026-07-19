-- 'peripherals' and 'programs' keys are skipped in config table
-- each key in config requires a key here, but not each key here is required to be present in the config (so no required keys)
-- value may be one of the following:
-- "type" a string containing the type as string, as returned by type()
-- { "type",  "type" } a table containing multiple allowed types as strings, as returned by type()
-- { type = "enum", ... } a table containing all allowed values for this key
local configTypes = {
    auto_migrate = "boolean",
    exists_handle_method = { type = "enum", "overwrite", "skip" }, -- overwrite,skip
    data = "table",
    channels = "table",
}

function joinPath(a, b)
    assert(b ~= nil, "Can not join nil to a path")
    if a == nil then
        return b
    else
        return a .. "." .. b
    end
end

function createForAll(group, func, callers, path)
    if type(group) == "string" then
        table.insert(callers, function()
            func(path, group)
        end)
    elseif type(group) == "table" then
        for name, subgroup in pairs(group) do
            local subpath = joinPath(path, name)
            createForAll(subgroup, func, callers, subpath)
        end
    else
        valid = false
        term.setTextColor(colors.red)
        print(
            ("Invalid entry at %s: Value is of type %s, expected string or table"):format(
                path,
                type(group)
            )
        )
        term.setTextColor(colors.white)
    end
end

return function(config)
    valid = true
    local validationInfo = {
    }
    -- validate peripherals
    local total = 0
    local present = 0
    local callers = {}
    createForAll(
        config.peripherals,
        function(path, name)
            local configName = path:match("[^.]+$") or path
            local myConfigName = "computer" .. tostring(os.getComputerID())
            total = total + 1

            if peripheral.isPresent(name) or configName:sub(1, #myConfigName) == myConfigName then -- Also present if its yourself
                present = present + 1
                if configName:sub(1, #myConfigName) == myConfigName then return end
            else
                valid = false
                term.setTextColor(colors.orange)
                print(
                    ("Peripheral at %s is not present: %s"):format(
                        path,
                        name
                    )
                )
                term.setTextColor(colors.white)
                return
            end

            local periphType = peripheral.getType(name)
            local periphTypeSimple = periphType:match("[^:]+$")
            if periphTypeSimple:sub(1,7) == "Create_" then periphTypeSimple = periphTypeSimple:sub(8) end
            if periphType == "computer" then -- ex. "computer71"
                periphType = periphType .. tostring(peripheral.call(name, "getID"))
            end
            if configName:sub(1, #periphType):lower() ~= periphType:lower() and configName:sub(1, #periphTypeSimple):lower() ~= periphTypeSimple:lower() then
                valid = false
                term.setTextColor(colors.orange)
                print(
                    ("Peripheral at %s should start with type: %s"):format(
                        path,
                        periphType == periphTypeSimple and ("'%s'"):format(periphType) or
                        ("'%s' or '%s'"):format(periphType, periphTypeSimple)
                    )
                )
                term.setTextColor(colors.white)
            end
        end,
        callers,
        "peripherals"
    )

    parallel.waitForAll(table.unpack(callers))
    validationInfo.peripheralTotal = total
    validationInfo.peripheralPresent = present

    print(("Validated config.peripherals with %d/%d peripherals present."):format(
        validationInfo.peripheralPresent, validationInfo.peripheralTotal
    )) -- log:info

    -- validate programs
    local total = 0
    local present = 0

    local function validateProgram(id, data)
        if data.name == nil or data.name == "" then
            term.setTextColor(colors.orange)
            print(
                ("Program %d: A `name` is required."):format(
                    id
                )
            )
            term.setTextColor(colors.white)
            return false
        end
        if data.location == nil or data.location == "" then
            term.setTextColor(colors.orange)
            print(
                ("Program %d: A filepath ('location') pointing to the entrypoint is required. (if a directory is provided, ?/init.lua will be used)")
                :format(
                    id
                )
            )
            term.setTextColor(colors.white)
            return false
        end
        if data.description == nil or data.description == "" then
            term.setTextColor(colors.yellow)
            print(
                ("Program %d: Please add a description for this program."):format(
                    id
                )
            )
            term.setTextColor(colors.white)
        end

        for _, key in ipairs({ "name", "location", "description" }) do
            if type(data[key]) ~= "string" then
                term.setTextColor(colors.orange)
                print(
                    ("Program %d: '%s' must be of type string, not %s")
                    :format(
                        id, key, type(data[key])
                    )
                )
                term.setTextColor(colors.white)
                return false
            end
        end
        return true
    end

    for id, data in ipairs(config.programs) do
        total = total + 1
        local programValid = validateProgram(id, data)
        if programValid then
            present = present + 1
        end
        valid = valid and programValid
    end

    validationInfo.programTotal = total
    validationInfo.programValid = present

    print(("Validated config.programs with %d/%d programs valid."):format(
        validationInfo.programValid, validationInfo.programTotal
    )) -- log:info

    -- validate settings and other
    local function validateSetting(key, value)
        local requiredType = configTypes[key]
        if requiredType == nil then
            term.setTextColor(colors.orange)
            print(
                ("Config value at '%s' has no configured type, please configure in /lib/config/validate.lua"):format(
                    key
                )
            )
            term.setTextColor(colors.white)
            return false
        end
        if type(requiredType) == "string" then
            if type(value) == requiredType then
                return true
            else
                term.setTextColor(colors.red)
                print(
                    ("Invalid config value at %s: Value is of type %s, expected %s"):format(
                        key, type(value), requiredType
                    )
                )
                term.setTextColor(colors.white)
                return false
            end
        elseif type(requiredType) == "table" then
            if requiredType.type == nil then
                local correctType = false
                for _, acceptedType in ipairs(requiredType) do
                    correctType = correctType or type(value) == acceptedType
                end
                if not correctType then
                    term.setTextColor(colors.red)
                    print(
                        ("Invalid config value at %s: Value is of type %s, expected one of %s"):format(
                            key, type(value), table.concat(requiredType, ", ")
                        )
                    )
                    term.setTextColor(colors.white)
                end
                return correctType
            elseif requiredType.type == "enum" then
                local inEnum = false
                for _, enumValues in ipairs(requiredType) do
                    inEnum = inEnum or value == enumValues
                end
                if not inEnum then
                    term.setTextColor(colors.red)
                    print(
                        ("Invalid config value at %s: Value %s is not in %s"):format(
                            key, textutils.serialise(value),
                            textutils.serialise({ table.unpack(requiredType) }) -- unpack and repack to remove type = "enum"
                        )
                    )
                    term.setTextColor(colors.white)
                end
                return inEnum
            else
                term.setTextColor(colors.orange)
                print(
                    ("Configured type for '%s' has invalid type '%s', please configure in /lib/config/validate.lua")
                    :format(
                        key, requiredType.type
                    )
                )
                term.setTextColor(colors.white)
                return false
            end
        end
    end

    for key, value in pairs(config) do
        if key ~= "peripherals" and key ~= "programs" then
            valid = valid and validateSetting(key, value)
        end
    end

    -- return validation results

    return valid, validationInfo
end

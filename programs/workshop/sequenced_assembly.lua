package.path = package.path .. ";/lib/?.lua;/lib/?/init.lua"
local config = require "config"
local logic = require "logic"

local input_name = config.peripherals.workshop.assembly_line.barrel_input
local output = peripheral.wrap(config.peripherals.workshop.assembly_line.barrel_output)

local filter_size = 9
local invert_slot = 9
local placeholder_item = "minecraft:iron_bars"

local inverted = false

function contains(table, value)
    for _, v in pairs(table) do
        if v == value then
            return true
        end
    end
    return false
end

while true do
    local contents, size
    parallel.waitForAll(
        function() contents = output.list() end,
        function() size = output.size() end
    )
    local actionable = size - filter_size
    local filter = {}
    for slot = size - filter_size + 1, size do
        local item = contents[slot]
        if item ~= nil and item.name ~= placeholder_item then
            table.insert(filter, item.name)
        end
    end

    if invert_slot ~= nil and invert_slot > 0 then
        local item = contents[invert_slot]
        inverted = item ~= nil and item.name == placeholder_item
    end

    if #filter > 0 or inverted then
        local callers = {}
        for slot = 1, actionable do
            local item = contents[slot]
            if not (inverted and slot == invert_slot)
                and item ~= nil
                and logic.xor(inverted, contains(filter, item.name))
            then
                table.insert(callers, function()
                    local transfered = output.pushItems(input_name, slot)
                    print(("Transfered %d %s"):format(transfered, item.name))
                end)
            end
        end
        parallel.waitForAll(table.unpack(callers))
    end
end

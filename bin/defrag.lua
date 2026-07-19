package.path = package.path .. ";/lib/?.lua;/lib/?/init.lua"
local config = require "config"

local drawer = peripheral.wrap(config.peripherals.logistics.drawers)
local bulk_containers = config.peripherals.logistics.bulk

local in_drawers = {}
for slot, details in pairs(drawer.list()) do
    in_drawers[details.name] = slot
end

function defragContainer(name)
    local container = peripheral.wrap(name)
    for slot, details in pairs(container.list()) do
        if in_drawers[details.name] ~= nil then -- in drawer system
            local drawer_slot = in_drawers[details.name]
            local transfered = drawer.pullItems(name, slot)
            if transfered < details.count then
                print(("Drawer '%s' requires upgrade: %d remaining"):format(details.name, details.count - transfered))
            else
                print(("Defragged %d items to drawer '%s'"):format(transfered, details.name))
            end
        end
    end
end

for _, container_name in ipairs(bulk_containers) do
    defragContainer(container_name)
end

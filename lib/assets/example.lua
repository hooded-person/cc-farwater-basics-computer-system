local base = require "init"

local chests = { peripheral.find("minecraft:chest") }

local base_dir = "/potions/item"

local potions = base.loadNamespaced(base_dir, base.loader.basic)

function collect(chest, slot)
    local details = chest.getItemDetail(slot)
    if details == nil then return end
    if potions[details.name] == nil then
        potions[details.name] = {}
    end
    potions[details.name][details.nbt] = {
        displayName = details.displayName,
        nbt = details.nbt,
        potionEffects = details.potionEffects,
    }
end

local callers = {}

for _, chest in ipairs(chests) do
    local size = chest.size()
    for slot = 1, size do
        table.insert(callers, function() collect(chest, slot) end)
    end
end

parallel.waitForAll(table.unpack(callers))

base.unloadNamespaced(base_dir, base.saver.basic, potions)
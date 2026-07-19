local hunger = {
    ["create:honeyed_apple"] = 8,
}
local foodSlot = 8
local maxOvershoot = 0
local minHealth = -1

-- static variables, might be different because of other mods
local maxHunger = 20
local maxHealth = 20

-- update config variables based on static variables
minHealth = minHealth == -1 and maxHealth or minHealth

print("Auto feeder running")

while true do
    local info = link.getInfo()
    local foodItem = link.getSlot(foodSlot)
    if foodItem == nil or info == nil then
        print(("no item in slot %d or link not loaded fully i guess"):format(foodSlot))
    elseif hunger[foodItem.name] ~= nil then
        local itemHunger = hunger[foodItem.name]
        if info.health < minHealth then
            link.consume(foodSlot)
        elseif info.hunger + itemHunger <= maxHunger + maxOvershoot then
            link.consume(foodSlot)
        end
    end
end

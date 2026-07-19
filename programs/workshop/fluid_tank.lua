package.path = package.path .. ";/lib/?.lua;/lib/?/init.lua"
local config = require "config"

local tank = peripheral.wrap(config.peripherals.workshop.assembly_line.fluid_tank)
local monitor = peripheral.wrap(config.peripherals.workshop.assembly_line.monitor_tank_contents)

local theme = {
    fluid = colors.gray,
    empty = colors.black,
    text = colors.white,
    bg = colors.black,
}

function getFluidColor(name)
    if fs.exists("/disk/colors/fluids.lon") then
        local h = fs.open("/disk/colors/fluids.lon", "r")
        local contents = h.readAll():gsub("^return *", "")
        h.close()
        local fluids = textutils.unserialise(contents)
        if fluids[name] then
            return fluids[name]
        elseif fluids["minecraft:water"] then
            return fluids["minecraft:water"]
        end
    end
    return 0x808080
end

function getFluidRGB(name)
    return colors.unpackRGB(getFluidColor(name))
end

function getPotionColor(nbt)
    if fs.exists("/disk/colors/potions.lon") then
        local h = fs.open("/disk/colors/potions.lon", "r")
        local contents = h.readAll()
        h.close()
        local potions = textutils.unserialise(contents)
        if potions[nbt] then
            return potions[nbt]
        end
    end
    return getFluidColor("minecraft:water")
end

function getPotionRGB(name)
    return colors.unpackRGB(getPotionColor(name))
end

monitor.setTextColor(theme.fluid)
monitor.setBackgroundColor(theme.empty)
monitor.setTextScale(0.5)
monitor.clear()

local w, h = monitor.getSize()

local contents_height = 3

local window_bar = window.create(monitor, 1, 1, w, h - contents_height)
local window_bar_height = h - contents_height
local window_contents = window.create(monitor, 1, h - contents_height, w, contents_height)

function updateBar(transition_y, transition_type)
    window_bar.setVisible(false)
    window_bar.clear()
    window_bar.setCursorPos(1, window_bar_height - transition_y)

    local transition_char, fg, bg
    if transition_type == 0 then
        transition_char = "\x80"
        fg = colors.toBlit(theme.fluid)
        bg = colors.toBlit(theme.empty)
    elseif transition_type == 1 then
        transition_char = "\x8F"
        fg = colors.toBlit(theme.empty)
        bg = colors.toBlit(theme.fluid)
    elseif transition_type == 2 then
        transition_char = "\x83"
        fg = colors.toBlit(theme.empty)
        bg = colors.toBlit(theme.fluid)
    end
    window_bar.blit(
        transition_char:rep(w),
        fg:rep(w),
        bg:rep(w)
    )

    for y = window_bar_height - transition_y + 1, window_bar_height do
        window_bar.setCursorPos(1, y)
        window_bar.blit(
            ("\x80"):rep(w),
            colors.toBlit(theme.empty):rep(w),
            colors.toBlit(theme.fluid):rep(w)
        )
    end

    window_bar.setVisible(true)
end

function updateText(name, amount, max)
    window_contents.setVisible(false)
    window_contents.setTextColor(theme.text)
    window_contents.setBackgroundColor(theme.bg)
    window_contents.clear()

    local nice_name = name:match("[^:]+$")
        :gsub("_", " ")
        :gsub("[^ ]+", function(match)
            return match:sub(1, 1):upper() .. match:sub(2)
        end)

    window_contents.setCursorPos(math.ceil(w / 2 - #nice_name / 2), 2)
    window_contents.write(nice_name)

    local amountStr = ("%.2f/%.1f B"):format(amount / 1000, max / 1000)
    window_contents.setCursorPos(math.ceil(w / 2 - #amountStr / 2), 3)
    window_contents.write(amountStr)

    window_contents.setVisible(true)
end

while true do
    local contents, capacity
    parallel.waitForAll(
        function() contents = tank.tanks()[1] end,
        function() capacity = tank.capacities()[1] end
    )

    local r, g, b
    if contents.name == "create:potion" then
        r, g, b = getPotionRGB(contents.nbt)
    else
        r, g, b = getFluidRGB(contents.name)
    end
    window_contents.setPaletteColor(theme.fluid, r, g, b)

    local fill_percentage = contents.amount / capacity
    local bar_height = math.floor(fill_percentage * (h - contents_height) * 3)
    local transition_y = math.floor(bar_height / 3) + 1
    local transition_type = math.mod(bar_height, 3)

    updateBar(transition_y, transition_type)
    updateText(contents.name, contents.amount, capacity)
end

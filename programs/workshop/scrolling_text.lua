package.path = package.path .. ";/lib/?.lua;/lib/?/init.lua"
local config = require "config"
local disk = require "disk" (config.peripherals.main.drive_main)


local scroll_delay = 0.5
local spacing = 5
local y = 1
local fg = colors.white
local bg = colors.black

local monitor = peripheral.wrap(config.peripherals.workshop.screens.monitor_wide)
monitor.setTextScale(3)
local w, h = monitor.getSize()
monitor.setTextColor(fg)
monitor.setBackgroundColor(bg)
monitor.clear()

local win = window.create(monitor, 1, 1, w, h)

function getLine()
    -- Get configured lines (allows changing without restarting program)
    local h = fs.open(disk("data/lines.txt"), "r")
    local contents = h.readAll()
    h.close()
    local lines = {}
    for line in contents:gmatch("[^\n]+") do
        table.insert(lines, line)
    end

    -- Pick a line
    local lineI = math.floor(math.random() * #lines) + 1
    return lines[lineI]
end

local offset = 0
local lines = {}

while true do
    local linesWidth = (#lines - 1) * spacing
    for _, line in ipairs(lines) do
        linesWidth = linesWidth + #line
    end
    while linesWidth - offset < w do
        local newLine = getLine()
        linesWidth = linesWidth + (#lines == 0 and 0 or spacing) + #newLine
        table.insert(lines, newLine)
    end

    win.setVisible(false)
    win.setCursorPos(1 - offset, y)
    win.clear()
    for _, line in ipairs(lines) do
        win.write(line)
        win.write((" "):rep(spacing))
    end
    win.setVisible(true)

    while offset > #lines[1] + spacing do
        local removedLine = table.remove(lines, y)
        local removedWidth = #removedLine + spacing
        offset = offset - removedWidth - 1
    end

    offset = offset + 1
    sleep(scroll_delay)
end

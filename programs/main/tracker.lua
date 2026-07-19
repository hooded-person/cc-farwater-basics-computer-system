package.path = package.path .. ";/lib/?.lua;/lib/?/init.lua"
local config = require "config"

local detector = peripheral.wrap(config.peripherals.server_room.player_detector)

local pos = vector.new(-2064, 52, -1563) --vector.new(gps.locate())

local monitor = peripheral.wrap(config.data.prog_tracker.monitor)
monitor.clear()
local monW, monH = monitor.getSize()
local win = window.create(monitor, 1, 1, monW, monH)

function trackPlayer(playername)
    local player = detector.getPlayer(playername)
    player.name = playername

    if player.x ~= nil and player.y ~= nil and player.z ~= nil then
        player.detected = true
        player.pos = vector.new(player.x, player.y, player.z)
        player.distance = (pos - player.pos):length()
    else
        player.detected = false
    end

    return player
end

while true do
    local online = detector.getOnlinePlayers()

    local players = {}
    local callers = {}
    for _, playername in ipairs(online) do
        table.insert(callers, function() table.insert(players, trackPlayer(playername)) end)
    end

    parallel.waitForAll(table.unpack(callers))

    table.sort(players, function(a, b)
        if a.detected and b.detected then
            return a.distance < b.distance
        else                       -- not a.detected or not b.detected
            if a.detected then     --     a.detected -> not b.detected | a should go first
                return true
            else                   -- not a.detected -> b.detected or not b.detected
                if b.detected then --     b.detected | b should go first
                    return false
                else               -- not b.detected | sort by username
                    return a.name < b.name
                end
            end
        end
    end)

    local rows = {
        { "Username", "X", "Y", "Z", "Health", "Distance" }
    }
    local detected = {}
    local widths = {}
    for i, v in ipairs(rows[1]) do
        widths[i] = #v
    end

    for _, player in ipairs(players) do
        local health = player.health and tostring(math.floor(player.health)) or "?"
        local maxHealth = player.maxHealth and tostring(math.floor(player.maxHealth)) or "?"
        local distance = player.distance and ("%.2f"):format(player.distance) or "?"
        local row = {
            player.name,
            tostring(player.x or "?"), tostring(player.y or "?"), tostring(player.z or "?"),
            health .. "/" .. maxHealth,
            distance
        }
        table.insert(rows, row)
        detected[#rows] = player.detected
        for i, v in ipairs(row) do
            widths[i] = #v > widths[i] and #v or widths[i]
        end
    end

    win.setVisible(false)
    for y, row in ipairs(rows) do
        if y == 1 then
            win.setBackgroundColor(colors.gray)
        else
            win.setBackgroundColor(colors.black)
            if detected[y] then
                win.setTextColor(colors.white)
            else
                win.setTextColor(colors.lightGray)
            end
        end
        win.setCursorPos(1, y)
        win.clearLine()

        local x = 1
        for i, chunk in ipairs(row) do
            win.setCursorPos(x, y)
            win.write(row[i])
            x = x + 1 + widths[i]
        end
    end
    win.setVisible(true)
end

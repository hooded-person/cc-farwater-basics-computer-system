package.path = package.path .. ";/lib/?.lua;/lib/?/init.lua"
local config = require "config"
local ecnet2 = require "ecnet2"
local random = require "ccryptolib.random"
local player_head = require "player_head"

-- CONFIG

local token = "43ac378a760cfd05133891ed6b554a9c08d3"
local player_info_config = {
    interval = 5 -- update interval in seconds
}

-- END CONFIG

local monitor = peripheral.wrap(config.data.prog_remote_link.monitor)
monitor.clear()
monitor.setCursorPos(1, 1)
monitor.setTextScale(1)
local w, h = monitor.getSize()
local win = window.create(monitor, 1, 1, w, h)


local modems = { peripheral.find("modem") }
local modem_name
for i, candidate in ipairs(modems) do
    local name = peripheral.getName(candidate)
    if candidate.isWireless() then
        modem_name = peripheral.getName(candidate)
        break
    end
end

if modem_name == nil then
    error("No wireless modem available")
end
print("Hosting server using modem '" .. modem_name .. "'")

-- Initialize the random generator.
local postHandle = assert(http.post("https://krist.dev/ws/start", "{}"))
local data = textutils.unserializeJSON(postHandle.readAll())
postHandle.close()
random.init(data.url)
http.websocket(data.url).close()

-- Open the top modem for comms.
ecnet2.open(modem_name)

-- Define an identity.
local id = ecnet2.Identity("/.ecnet2")

-- Define a protocol.
local proto_info = id:Protocol {
    name = "kg.cclink.info",
    serialize = textutils.serialize,
    deserialize = textutils.unserialize,
}

-- The listener so we can look for and accept incoming connections.
local listener = proto_info:listen()

-- The set of accepted connections.
local connections = {}

local function renderPlayerHead(name)
    -- head is 8x8, 1px = 2/3 char height -> 5 1/3 char height
    local w, h = win.getSize()
    local x = 2 -- 8 chars wide

    local img = {}
    local img_w, img_h = 8, 8
    local lines = {}

    local c = {
        { "0", "3" },
        { "6", "c" }
    }

    -- gen mock head
    term.clear()
    for i = 1, 8 do
        img[i] = {}
        for j = 1, 8 do
            img[i][j] = c[i % 2 + 1][j % 2 + 1]
            term.setCursorPos(j, i)
            write(img[i][j])
        end
    end

    -- convert to blit lines
    local lineHeight = math.ceil(8 * 2 / 3)
    local top = true
    local flipped = false
    for y = 1, lineHeight do
        local line = (top and "\x8F" or "\x83"):rep(img_w)
        local fg, bg = "", ""
        for img_x = 1, img_w do
            local color1 = img[y][img_x]
            local color2 = img[y + 1][img_x]
            -- XOR top flipped
            if (top or flipped) and not (top and flipped) then
                fg = fg .. color1
                bg = bg .. color2
            else
                fg = fg .. color2
                bg = bg .. color1
            end
        end
        lines[y] = { line, fg, bg }
        top = not top
        if y % 2 == 1 then
            flipped = not flipped
        end
    end

    -- display blit lines
    for i, v in ipairs(lines) do
        win.setCursorPos(x, i + 1)
        win.blit(table.unpack(v))
    end
end

local function updateMonitor(player_info)
    win.setVisible(false)
    win.clear()

    -- mock player head
    -- renderPlayerHead(player_info.name)
	player_head.drawPlayerHead(2, 2, player_info.name, win)

    -- player name
    win.setCursorPos(12, 2)
    win.write(player_info.name)

    -- health
    win.setCursorPos(12, 3)
    local health_str      = tostring(player_info.health) .. "/" .. tostring(player_info.max_health)
    local bar_w           = w - 12 - (#tostring(player_info.max_health) * 2 + 2)
    local bar, fg, bg
    local fill_percentage = player_info.health / player_info.max_health
    local fill_slices     = math.floor(bar_w * 2 * fill_percentage)
    bar                   = ("\x80"):rep(math.floor(fill_slices / 2))
    fg                    = ("7"):rep(math.floor(fill_slices / 2))
    bg                    = ("e"):rep(math.floor(fill_slices / 2))
    if fill_slices % 2 == 1 then
        bar = bar .. "\x95"
        fg = fg .. "e"
        bg = bg .. "7"
    end
    bar = bar .. ("\x80"):rep(bar_w - math.ceil(fill_slices / 2))
    fg  = fg .. ("e"):rep(bar_w - math.ceil(fill_slices / 2))
    bg  = bg .. ("7"):rep(bar_w - math.ceil(fill_slices / 2))
    win.blit(bar, fg, bg)

    win.setCursorPos(12 + bar_w + 1 + #tostring(player_info.max_health) - #tostring(player_info.health), 3)
    win.write(health_str)

    win.setVisible(true)
end

local function makeSender(connection)
    return function(msg)
        if type(msg) == "table" then
            local epoch = tostring(os.epoch("utc"))
            msg.id = epoch .. random.random(32 - #epoch)
        end
        connection:send(msg)
    end
end
local function main()
    while true do
        local event, id, p2, p3, ch, dist = os.pullEvent()
        if event == "ecnet2_request" and id == listener.id then
            local connection = listener:accept("auth_required", p2)
            connections[connection.id] = { conn = connection, auth = false, send = makeSender(connection) }
        elseif event == "ecnet2_message" and connections[id] then
            if not connections[id].auth then
                if p3 == token then
                    connections[id].auth = true
                    connections[id].conn:send("auth_success")
                    connections[id].conn:send({
                        type = "configuration",
                        data = player_info_config
                    })
                else
                    connections[id].conn:send("auth_failed")
                    connections[id] = nil
                end
            else
                local msg = p3
                if msg.type == "error" then
                    term.setTextColor(colors.red)
                    print("An error occured", msg.data)
                    term.setTextColor(colors.white)
                elseif msg.type == "send_player_info" then
                    local player_info = msg.data
                    updateMonitor(player_info)
                end
            end
        end
    end
end

parallel.waitForAny(main, ecnet2.daemon)

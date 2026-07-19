package.path = package.path .. ";/lib/?.lua;/lib/?/init.lua"
local config = require "config"

function wrappedWrite(mon, str)
    local w, h = mon.getSize()
    local lines = math.ceil(#str / w)
    for y = 1, lines do
        local chunk = str:sub((y - 1) * w, y * w - 1)
        mon.setCursorPos(1, y)
        mon.write(chunk)
    end
end

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
        print(
            ("Invalid entry at %s: Value is of type %s, expected string or table"):format(
                path,
                type(group)
            )
        )
    end
end

function runForAll(group, func, path)
    local callers = {}
    createForAll(group, func, callers, path)

    parallel.waitForAll(table.unpack(callers))
end

-- sub commands

-- id,identify
function monitorShowId(peripheral_name, peripheral_id)
    if peripheral.getType(peripheral_id) == "monitor" then
        local mon = peripheral.wrap(peripheral_id)
        mon.setTextColor(colors.white)
        mon.setBackgroundColor(colors.black)
        mon.clear()
        wrappedWrite(mon, peripheral_name)
    end
end

-- clr,cls,clear
function monitorClear(peripheral_name, peripheral_id)
    if peripheral.getType(peripheral_id) == "monitor" then
        local mon = peripheral.wrap(peripheral_id)
        mon.setTextColor(colors.white)
        mon.setBackgroundColor(colors.black)
        mon.clear()
    end
end

local args = { ... }

local subcommands = {
    identify = {
        all = true, func = monitorShowId, desc = "Identify configured monitors by full config path"
    },
    id = "identify",
    clear = {
        all = true, func = monitorClear, desc = "Clear all monitors"
    },
    clr = "clear",
    cls = "clear",
}
local function resolveSubCmd(cmd)
    while true do
        local cmdInfo = subcommands[cmd]
        if cmdInfo == nil then
            return false, nil
        elseif type(cmdInfo) == "string" then
            return resolveSubCmd(cmdInfo)
        elseif type(cmdInfo) == "table" then
            return true, cmdInfo
        end
    end
end

local valid, subcommand = resolveSubCmd(args[1])

if not valid then -- help
    local cmds = {}
    for cmd, info in pairs(subcommands) do
        if type(info) == "string" then
            if cmds[info] == nil then
                cmds[info] = { alias = {} }
            end
            if cmds[info].alias == nil then
                cmds[info].alias = {}
            end

            table.insert(cmds[info].alias, cmd)
        elseif type(info) == "table" then
            if cmds[cmd] == nil then
                cmds[cmd] = {}
            end

            for k, v in pairs(info) do
                cmds[cmd][k] = v
            end
        end
    end

    local lines = {}
    local lengths = { 0, 0, 0, 0 }
    for cmd, info in pairs(cmds) do
        local sep = info.all and "=" or "-"
        local desc = info.desc and info.desc or ""
        local alias = (info.alias == nil or #info.alias == 0) and "" or ("(%s)"):format(table.concat(info.alias, ","))

        local line = {
            cmd,
            sep,
            desc,
            alias
        }

        for i, v in ipairs(line) do
            if #v > lengths[i] then
                lengths[i] = #v
            end
        end

        table.insert(lines, line)
    end

    print("==[ Monitor toolkit ]==")
    local w, h = term.getSize()
    local y = select(2, term.getCursorPos())
    for i, line in pairs(lines) do
        local y = math.min(y + i - 1, h)
        term.setCursorPos(1, y)
        write(line[1])

        term.setCursorPos(lengths[1] + 2, y)
        write(line[2])
        term.setCursorPos(w - lengths[4], y)
        write(line[4])

        if y >= h then
            term.scroll(1)
        end
        term.setCursorPos(1, y)
    end
    print("= runs for all, - runs single")
elseif subcommand.all then
    local subset_path = table.concat(
        { select(2, table.unpack(args)) },
        " "
    )

    local t = config.peripherals
    local prev = nil
    for path_part in subset_path:gmatch("[^.]+") do
        local subt = t[path_part]
        if subt == nil then
            print(("Table '%s' does not exist in %s"):format(
                path_part,
                prev ~= nil and "'" .. prev .. "'" or "the peripheral config table"
            ))
            return
        end
        t = subt
        prev = prev == nil and path_part or prev .. "." .. path_part
    end

    runForAll(t, subcommand.func, prev)
else
    subcommand.func(
        select(2, table.unpack(args))
    )
end

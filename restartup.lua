local files = fs.list("/startup")

local args = {...}
local argStr = table.concat(args, " ")

local exclude = { "0-remote.lua" }

if argStr:find("-t") or argStr:find("--terminal") then
    table.insert(exclude, "20-launch_programs.lua")
end

local excludeMap = {}

for _, file in ipairs(exclude) do
    excludeMap["/" .. fs.combine("startup", file)] = true
end

local function findStartups(sBaseDir)
    local tStartups = nil
    local sBasePath = "/" .. fs.combine(sBaseDir, "startup")
    local sStartupNode = shell.resolveProgram(sBasePath)
    if sStartupNode then
        tStartups = { sStartupNode }
    end
    -- It's possible that there is a startup directory and a startup.lua file, so this has to be
    -- executed even if a file has already been found.
    if fs.isDir(sBasePath) then
        if tStartups == nil then
            tStartups = {}
        end
        for _, v in pairs(fs.list(sBasePath)) do
            local sPath = "/" .. fs.combine(sBasePath, v)
            if not fs.isDir(sPath) then
                tStartups[#tStartups + 1] = sPath
            end
        end
    end
    return tStartups
end

local tUserStartups = findStartups("/")

for _, v in pairs(tUserStartups) do
    if not excludeMap[v] then
        shell.run(v)
    end
end

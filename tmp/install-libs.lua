-- Install libs not synced to disk because of file sizes (see main computer:/startup/11-sync_code.lua:L23)
-- because of rate limits, this will not download if the folders already exist

local installDir = "/lib/"
local repos = {
    "https://api.github.com/repos/migeyel/ecnet/contents/ecnet2",
    "https://api.github.com/repos/migeyel/ccryptolib/contents/ccryptolib",
}

local function downloadFile(path, url)
    shell.run("wget " .. url .. " " .. path)
end

local function downloadRepoDir(baseDir, url)
    print("downloading repo '" .. url .. "'")
    if fs.exists(baseDir) then
        print("'"..baseDir.."' already exists, assuming already installed. (anti-ratelimit measure)")
    end

    ---@type table
    local res = http.get(url)
    local code = res.getResponseCode()
    -- local headers = res.getResponseHeaders()
    local body_raw = res.readAll and res.readAll()
    if code < 200 or code > 299 then
        res.close()
        if code == 429 then
            error("ratelimited, can not continue")
        end
        return false, string.format("HTTP %d: %s", code, body_raw)
    end
    local body = textutils.unserialiseJSON(body_raw)
    for i, item in ipairs(body) do
        if item.type == "dir" then
            downloadRepoDir(
                baseDir .. "/" .. item.name,
                url .. "/" .. item.name
            )
        elseif item.type == "file" then
            downloadFile(
                "/" .. fs.combine(baseDir, item.name),
                item.download_url
            )
        else
            print(("Unkown type '%s' for item at path '%s'"):format(item.type, item.path))
        end
    end
end

for path, repo in pairs(repos) do
    local dir = installDir
    if type(path) == "string" then
        dir = "/" .. fs.combine(dir, path)
    else
        local s, _ = repo:find("/[^/]+$")
        dir = "/" .. fs.combine(dir, repo:sub(s + 1))
    end
    if type(repo) == "string" then
        downloadRepoDir(dir, repo)
    elseif type(repo) == "table" then
        for _, repo_url in ipairs(repo) do
            downloadRepoDir(dir, repo_url)
        end
    end
end

print("All libs installed")

local remote = "kg-fw-basic-main"

if remote ~= nil and remote ~= "" then
    shell.run(("wget run https://remote.craftos-pc.cc/server.lua %s"):format(remote))
end

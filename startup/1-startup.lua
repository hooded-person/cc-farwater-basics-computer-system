-- settings
settings.set("shell.allow_disk_startup", false)
settings.set("list.show_hidden", true)
settings.set("motd.path", "/rom/motd.txt:/motd.txt")

settings.save()

-- add bin to path
local path = shell.path()
path = path .. ":" .. "/bin"
shell.setPath(path)

-- aliases
shell.setAlias("mon","monitors")
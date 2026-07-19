return function(drive_name)
    if not disk.hasData(drive_name) then
        return nil, ("drive '%s' contains no disk"):format(drive_name)
    end

    local mount = disk.getMountPath(drive_name)

    local prefix = "/" .. fs.combine(mount) .. "/"

    return function(path)
        return prefix .. fs.combine(path)
    end
end

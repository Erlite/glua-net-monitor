AddCSLuaFile()

NetMonitor = NetMonitor or {}
NetMonitor.Utils = NetMonitor.Utils or {}

-- Surrogates for file.Exists() and file.IsDir() for directories
function NetMonitor.Utils.DirExists(name, path)
    if SERVER then return file.IsDir(name, path) end
    if file.IsDir(name, path) then return true end

    path = string.TrimRight(path, "/")
    local _, dirs = file.Find(name .. "*", path)
    if dirs == nil or #dirs == 0 then return false end

    local splits = string.Split(name, "/")
    local dirName = splits[#splits]
    
    return table.HasValue(dirs, dirName)
end

function NetMonitor.Utils.PathExists(name, path)
    return file.Exists(name, path) or (CLIENT and DirExists(name, path))
end
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

function NetMonitor.Utils.ChatError(msg)
    if CLIENT then 
        chat.AddText(Color(255, 90, 90), "NetMonitor: " .. msg)
    end
end

function NetMonitor.Utils.ClampToScreen(w, h)
    return math.min(ScrW(), w), math.min(ScrH(), h)
end

function NetMonitor.Utils.StringMatchesSearch(searchTerm, string)
    if #searchTerm == 0 then return true end
    
    local goodPattern, pos = pcall(string.find, path, searchTerm)
    if not goodPattern then
        local pos, _, _ = string.find(path, searchTerm, 1, true)
        return pos != nil
    end

    return pos != nil
end

function NetMonitor.Utils.VerifyDataFolders()
    local neededCreation = false

    if not file.IsDir("netmon", "DATA") then
        neededCreation = true
        file.CreateDir("netmon")
    end

    if CLIENT and not file.IsDir("netmon/client", "DATA") then
        neededCreation = true
        file.CreateDir("netmon/client")
    end

    if not file.IsDir("netmon/server", "DATA") then
        neededCreation = true
        file.CreateDir("netmon/server")
    end

    return neededCreation
end
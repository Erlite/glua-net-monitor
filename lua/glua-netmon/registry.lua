AddCSLuaFile()

NetMonitor = NetMonitor or {}
NetMonitor.Registry = NetMonitor.Registry or {}
NetMonitor.Registry.AddonFiles = NetMonitor.Registry.AddonFiles or {}
NetMonitor.Registry.FileAddons = NetMonitor.Registry.FileAddons or {}
NetMonitor.Registry.ReceiveFiles = NetMonitor.Registry.ReceiveFiles or {}

local function RegisterDir(addonName, path)
    local files, _ = file.Find(path .. "/*.lua", "GAME")
    local _, dirs = file.Find(path .. "/*", "GAME")

    for _, f in ipairs(files) do 
        local p = string.Replace(path .. "/" .. f, "//", "/")
        NetMonitor.Registry.RegisterAddonFile(addonName, p)
    end

    for _, dir in ipairs(dirs) do
        local p = string.Replace(path .. "/" .. dir, "//", "/")
        RegisterDir(addonName, p)
    end
end

local function Initialize()
    if NetMonitor.Config.AutoRegisterGamemodeFiles then 
        NetMonitor.Registry.RegisterGamemodeFiles()
    end

    -- Addon files can only be auto registered server-side. 
    if SERVER and NetMonitor.Config.AutoRegisterAddonFiles then
        NetMonitor.Registry.RegisterAddonFiles()
    end
end

hook.Add("Initialize", "InitializeNetMonitorRegistry", Initialize)

function NetMonitor.Registry.RegisterGamemodeFiles()
    local gamemodePath = "gamemodes/" .. engine.ActiveGamemode() .. "/"
    local entitiesPath = gamemodePath .. "entities"
    local luaPath = gamemodePath .. "gamemode"

    if NetMonitor.Utils.DirExists(entitiesPath, "GAME") then
        -- Recursively load all files in the entities folder.
        RegisterDir(engine.ActiveGamemode(), entitiesPath)
    end

    if NetMonitor.Utils.DirExists(luaPath, "GAME") then
        RegisterDir(engine.ActiveGamemode(), luaPath)
    end
end

function NetMonitor.Registry.RegisterAddonFiles()
    if CLIENT then return end

    MsgC(Color(0, 255, 0), "NetMonitor: Registering all addon files.", "\n")

    local _, dirs = file.Find("addons/*", "GAME")
    for _, dir in pairs(dirs) do
        RegisterDir(dir, "addons/" .. dir .. "/")
    end
end

-- Registers a file as part of a specific addon. 
-- Used to map a net message's function info file to an addon name.
function NetMonitor.Registry.RegisterAddonFile(addonName, filePath)
    if not addonName or not isstring(addonName) then
        Error("Invalid addon name specified, expected string, got: " .. addonName or "nil")
        return
    end

    if not filePath or not isstring(filePath) then
        Error("Invalid file path specified, expected string, got: " .. filePath or "nil")
        return
    end

    MsgC(Color(0, 255, 0), "Registered file '" .. filePath .. "' to addon '" .. addonName .. "'\n")

    if not NetMonitor.Registry.AddonFiles[addonName] then 
        NetMonitor.Registry.AddonFiles[addonName] = {}
    end

    NetMonitor.Registry.AddonFiles[addonName][#NetMonitor.Registry.AddonFiles[addonName] + 1] = filePath
    NetMonitor.Registry.FileAddons[filePath:lower()] = addonName
end

function NetMonitor.Registry.RegisterReceiveFile(receivedMessage, filePath)
    if not receivedMessage or not isstring(receivedMessage) then
        Error("Invalid received message name specified, expected string, got: " .. receivedMessage or "nil")
        return
    end

    if not filePath or not isstring(filePath) then
        Error("Invalid file path specified, expected string, got: " .. filePath or "nil")
        return
    end

    NetMonitor.Registry.ReceiveFiles[receivedMessage:lower()] = filePath
end

function NetMonitor.Registry.GetAddonNameForFile(filePath)
    if not filePath or not isstring(filePath) then
        Error("Invalid file path specified, expected string, got: " .. filePath or "nil")
        return
    end

    return NetMonitor.Registry.AddonFiles[filePath:lower()] or "Unregistered Addon"
end

function NetMonitor.Registry.GetAddonNameFromReceivedMessage(messageName)
    if not messageName or not isstring(messageName) then
        Error("Invalid message name specified, expected string, got: " .. messageName or "nil")
        return
    end

    local filePath = NetMonitor.Registry.ReceiveFiles[messageName]
    if filePath then
        return NetMonitor.Registry.AddonFiles[filePath:lower()] or "Unregistered Addon"
    end

    return "Unregistered Addon"
end

function NetMonitor.Registry.IsMessageRegistered(msgName)
    if not msgName or not isstring(msgName) then
        Error("Invalid message name specified, expected string, got: " .. msgName or "nil")
        return
    end

    local path = NetMonitor.Registry.ReceiveFiles[msgName:lower()]
    if path then return NetMonitor.Registry.AddonFiles[path] != nil end

    return false
end

function NetMonitor.Registry.IsFileRegistered(filePath)
    if not filePath or not isstring(filePath) then
        Error("Invalid file path specified, expected string, got: " .. filePath or "nil")
        return
    end

    return NetMonitor.Registry.AddonFiles[filePath:lower()] != nil
end

function NetMonitor.Registry.GetAddonFiles(addon)
    if not addon or not isstring(addon) then
        Error("Invalid addon specified, expected string, got: " .. addon or "nil")
        return
    end

    return NetMonitor.Registry.AddonFiles[addon] or {}
end

local chunkSize = 64 * 1024
function NetMonitor.Registry.BuildRegistryChunks()
    -- Jsonify the table and compress it.
    local json = util.TableToJSON(NetMonitor.Registry.AddonFiles)
    local dat = util.Compress(json)

    -- Send them in chunks of 64kb
    local chunkAmount = math.ceil(#dat / chunkSize)
    local id = 1
    local chunks = {}

    repeat
        local subDat = string.sub(dat, 1, chunkSize)
        dat = string.sub(dat, chunkSize)
        print("sub: " .. subDat)
        local chunk = NetMonitor.BinaryChunk(id, chunkAmount, subDat)
        chunks[ #chunks + 1 ] = chunk
        id = id + 1
    until id > chunkAmount

    return chunks
end

function NetMonitor.Registry.UpdateFromChunks(chunks)
    local str = ""

    for _, chunk in ipairs(chunks) do
        str = str .. chunk:GetData()
    end

    local json = util.Decompress(str)
    local tbl = util.JSONToTable(json)

    table.Merge(NetMonitor.Registry.AddonFiles, tbl)
    hook.Run("OnNetRegistryUpdated")
end

MsgC(Color(0, 255, 0), "NetMonitor: Loaded registry", "\n")
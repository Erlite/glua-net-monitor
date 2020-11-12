--[[
    This file is a utility meant to map lua files of an addon to a name.
    Drop it in a folder and it will automatically grab all the lua files in current and all subdirs and map them to the given name.
    Remember: you need to include() it server-side, do it manually on the addon or something.
    
    If NetMonitor isn't installed, this file won't do anything.
--]]

AddCSLuaFile()

-- BEGIN THINGS YOU CAN AND SHOULD CHANGE
local AddonName = "ChangeMe"
local OtherDirectoriesToAdd = 
{
    -- "/lua/path/to/dir",
}
-- END THINGS YOU CAN AND SHOULD CHANGE. DO NOT TOUCH ANYTHING ELSE

local loadedDirs = {}

local function RegisterDir(path)
    local files, _ = file.Find(path .. "/*.lua", "GAME")
    local _, dirs = file.Find(path .. "/*", "GAME")

    for _, f in ipairs(files) do 
        local p = string.Replace(path .. "/" .. f, "//", "/")
        NetMonitor.Registry.RegisterAddonFile(AddonName, p)
    end

    for _, dir in ipairs(dirs) do
        local p = string.Replace(path .. "/" .. dir, "//", "/")
        if not loadedDirs[p] then
            RegisterDir(p)
            loadedDirs[p] = true
        end
    end
end

local function InitGrabFiles()
    if not NetMonitor or not NetMonitor.Registry then return end

    local info = debug.getinfo(1, "S")
    local path = info.short_src

    if path == nil then
        MsgC(Color(255, 90, 90), "NetMonitor: Failed to get the file path of an addon that wants to register itself. Addon name: ", AddonName or "nil", "\n")
        return
    end

    if not AddonName or not isstring(AddonName) then
        MsgC(Color(255, 90, 90), "NetMonitor: Cannot register non-string addon name. File: ", path, "\n")
        return
    end

    local splits = string.Split(path, "/")
    local fileName = splits[#splits]
    local dir = string.sub(path, 1, #path - #fileName)

    RegisterDir(dir)

    if #OtherDirectoriesToAdd > 0 then
        for i = 1, #OtherDirectoriesToAdd
            RegisterDir(OtherDirectoriesToAdd[i])
        end
    end
end

hook.Add("Initialize", "Initialize" .. AddonName or "nil", InitGrabFiles)
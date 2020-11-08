AddCSLuaFile()
print("Hello from hooks.lua")

local function OnNetMessageCaptured(msg, info)
    local json = util.TableToJSON(msg, true)
    print(json)
end

if SERVER then
hook.Add("OnNetMessageCaptured", "TestMessageCapture", OnNetMessageCaptured)
end
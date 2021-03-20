AddCSLuaFile()

local function OnNetMessageDiscarded(msg, funcInfo)
    MsgC(Color(255, 90, 90), "NetMonitor: The discarded message '", msg:GetName(), "' was started in file '", funcInfo and funcInfo.source or "NO SOURCE", "' at line ", funcInfo and funcInfo.currentline or "NO LINE")
    MsgC(Color(255, 90, 90), "NetMonitor: this means you likely forgot to send the message before starting another one.")
end

hook.Add("OnNetMessageDiscarded", "NetDiscarded", OnNetMessageDiscarded)
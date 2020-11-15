AddCSLuaFile()

NetMonitor = NetMonitor or {}
NetMonitor.ProfilingData = {}
NetMonitor.ProfilingData.__index = NetMonitor.ProfilingData

function NetMonitor.ProfilingData:new()
    local tbl = 
    {
        meta = "ProfilingData"
        stats = {}
        messages = {}
    }

    setmetatable(tbl, NetMonitor.ProfilingData)
    return tbl
end

function NetMonitor.ProfilingData:AddMessage(msg)
    if not msg or getmetatable(msg) != NetMonitor.CapturedMessage then
        Error("Cannot add message to profiled data, expected CapturedMessage, got: " .. msg or "nil")
        return
    end

    self.messages[ #self.messages + 1] = msg
end

setmetatable(NetMonitor.ProfilingData, {__call = NetMonitor.ProfilingData.new})
AddCSLuaFile()

NetMonitor = NetMonitor or {}
NetMonitor.ProfilingFilter = {}
NetMonitor.ProfilingFilter.__index = NetMonitor.ProfilingFilter

NetMonitor.ProfilingFilter.Flags = 
{
    None = 0,
    IncomingMessages = 1,
    OutgoingMessages = 2,
    NetLib = 4,
    UMsgLib = 8,
    SuccessfulMessages = 16,
    DiscardedMessages = 32,
    IgnoredMessages = 64,
    All = 255,
}

function NetMonitor.ProfilingFilter:new()
    local tbl =
    {
        flags = NetMonitor.ProfilingFilter.Flags.All,
        messageWhitelist = {},
        messageBlacklist = {},
    }

    setmetatable(tbl, NetMonitor.ProfilingFilter)
    return tbl
end

function NetMonitor.ProfilingFilter:DoesMessagePassFilter(msg)
    if not msg or getmetatable(msg) != NetMonitor.CapturedMessage then
        Error("Cannot check if message passes filter, expected CapturedMessage, got: " .. msg or "nil")
        return
    end

    if #self.messageWhitelist > 0 and not self.messageWhitelist[msg:GetName():lower()] then return false end

    if #self.messageBlacklist > 0 and self.messageBlacklist[msg:GetName():lower()] then return false end

    if not self:AllowsIncomingMessages() and msg:IsReceived() then return false end

    if not self:AllowsOutgoingMessages() and not msg:IsReceived() then return false end

    if not self:AllowsDiscardedMessages() and msg:IsDiscarded() then return false end

    if not self:AllowsIgnoredMessages() and msg:IsIgnored() then return false end

    if not self:AllowsSuccessfulMessages() and not msg:IsIgnored() and not msg:IsDiscarded() then return false end

    if not self:AllowsNetMessages() and not msg:IsDeprecated() then return false end

    if not self:AllowsUserMessages() and msg:IsDeprecated() then return false end

    return true
end

function NetMonitor.ProfilingFilter:WhitelistMessage(msg, value)
    self.messageWhitelist[msg:lower()] = value
end

function NetMonitor.ProfilingFilter:GetWhitelist()
    return self.messageWhitelist
end

function NetMonitor.ProfilingFilter:BlacklistMessage(msg, value)
    self.messageBlacklist[msg:lower()] = value
end

function NetMonitor.ProfilingFilter:GetBlacklist()
    return self.messageBlacklist
end

local function HasFlag(inFlag)
    return bit.band(self.flags, inFlag) > 0
end

local function SetFlag(inFlag)
    self.flags = bit.bor(self.flags, inFlag)
end

local function ClearFlag(inFlag)
    self.flags = bit.bxor(self.flags, inFlag)
end

function NetMonitor.ProfilingFilter:AllowsIncomingMessages()
    return HasFlag(NetMonitor.ProfilingFilter.Flags.IncomingMessages)
end

function NetMonitor.ProfilingFilter.SetAllowIncomingMessages(value)
    if value then SetFlag(NetMonitor.ProfilingFilter.Flags.IncomingMessages) else ClearFlag(NetMonitor.ProfilingFilter.Flags.IncomingMessages) end
end

function NetMonitor.ProfilingFilter:AllowsOutgoingMessages()
    return HasFlag(NetMonitor.ProfilingFilter.Flags.OutgoingMessages)
end

function NetMonitor.ProfilingFilter.SetAllowOutgoingMessages(value)
    if value then SetFlag(NetMonitor.ProfilingFilter.Flags.OutgoingMessages) else ClearFlag(NetMonitor.ProfilingFilter.Flags.OutgoingMessages) end
end

function NetMonitor.ProfilingFilter:AllowsNetMessages()
    return HasFlag(NetMonitor.ProfilingFilter.Flags.NetLib)
end

function NetMonitor.ProfilingFilter.SetAllowNetMessages(value)
    if value then SetFlag(NetMonitor.ProfilingFilter.Flags.NetLib) else ClearFlag(NetMonitor.ProfilingFilter.Flags.NetLib) end
end

function NetMonitor.ProfilingFilter:AllowsUserMessages()
    return HasFlag(NetMonitor.ProfilingFilter.Flags.UMsgLib)
end

function NetMonitor.ProfilingFilter.SetAllowUserMessages(value)
    if value then SetFlag(NetMonitor.ProfilingFilter.Flags.UMsgLib) else ClearFlag(NetMonitor.ProfilingFilter.Flags.UMsgLib) end
end

function NetMonitor.ProfilingFilter:AllowsSuccessfulMessages()
    return HasFlag(NetMonitor.ProfilingFilter.Flags.SuccessfulMessages)
end

function NetMonitor.ProfilingFilter.SetAllowSuccessfulMessages(value)
    if value then SetFlag(NetMonitor.ProfilingFilter.Flags.SuccessfulMessages) else ClearFlag(NetMonitor.ProfilingFilter.Flags.SuccessfulMessages) end
end

function NetMonitor.ProfilingFilter:AllowsDiscardedMessages()
    return HasFlag(NetMonitor.ProfilingFilter.Flags.DiscardedMessages)
end

function NetMonitor.ProfilingFilter.SetAllowDiscardedMessages(value)
    if value then SetFlag(NetMonitor.ProfilingFilter.Flags.DiscardedMessages) else ClearFlag(NetMonitor.ProfilingFilter.Flags.DiscardedMessages) end
end

function NetMonitor.ProfilingFilter:AllowsIgnoredMessages()
    return HasFlag(NetMonitor.ProfilingFilter.Flags.IgnoredMessages)
end

function NetMonitor.ProfilingFilter.SetAllowIgnoredMessages(value)
    if value then SetFlag(NetMonitor.ProfilingFilter.Flags.IgnoredMessages) else ClearFlag(NetMonitor.ProfilingFilter.Flags.IgnoredMessages) end
end

-- Net extensions
function net.WriteProfilingFilter(filter)
    if not filter or getmetatable(filter) != NetMonitor.ProfilingFilter then
        Error("Cannot write profiling filter to net, expected ProfilingFilter, got: " .. msg or "nil")
        return
    end

    net.WriteByte(filter)

    local whiteList = filter:GetWhitelist()
    net.WriteBool(#whiteList > 0)
        if #whiteList > 0 then
        net.WriteUInt(#whiteList, 16)

        for m, _ in pairs(whiteList) do
            net.WriteString(m)
        end
    end

    local blackList = filter:GetBlacklist()
    net.WriteBool(#blackList > 0)

    if #blackList > 0 then
        net.WriteUInt(#blackList, 16)

        for b, _ in pairs(blackList) do 
            net.WriteString(b)
        end
    end
end

function net.ReadProfilingFilter()
    local tbl = {}

    tbl.flags = net.ReadByte()
    tbl.messageWhitelist = {}
    tbl.messageBlacklist = {}

    if net.ReadBool() then
        local len = net.ReadUInt(16)

        for i = 1, len do
            local msg = net.ReadString()
            tbl.messageWhitelist[msg] = true
        end
    end

        if net.ReadBool() then
        local len = net.ReadUInt(16)

        for i = 1, len do
            local msg = net.ReadString()
            tbl.messageBlacklist[msg] = true
        end
    end

    setmetatable(tbl, NetMonitor.ProfilingFilter)
    return tbl
end

setmetatable(NetMonitor.ProfilingFilter, {__call = NetMonitor.ProfilingFilter.new})
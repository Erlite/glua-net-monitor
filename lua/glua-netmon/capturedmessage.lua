AddCSLuaFile()

NetMonitor = NetMonitor or {}

NetMonitor.CapturedMessage = {}
NetMonitor.CapturedMessage.__index = NetMonitor.CapturedMessage

function NetMonitor.CapturedMessage:new(msgName, isUnreliable)
    if !msgName or !isstring(msgName) then
        Error("Invalid message name passed in captured message constructor.")
    end

    isUnreliable = isUnreliable or false

    local msgSender = "SERVER"
    local msgSenderId = -1

    if CLIENT then 
        if !LocalPlayer() or !LocalPlayer().Nick or !LocalPlayer().SteamID64 then
            -- Client is still connecting.
            msgSender = "CONNECTING"
            msgSenderId = -1
        else
            msgSender = LocalPlayer():Nick()
            msgSenderId = LocalPlayer():SteamID64()
        end
    end

    local tbl = 
    {
        name = msgName,
        id = util.NetworkStringToID(msgName),
        unreliable = isUnreliable,
        deprecated = false,
        mode = nil,
        senderId = msgSenderId,
        senderName = msgSender,
        recipients = nil,
        bits = 0,
        wastedBits = 0,
        data = {},
    }

    setmetatable(tbl, NetMonitor.CapturedMessage)
    return tbl
end

-- Returns this message's name.
function NetMonitor.CapturedMessage:GetName()
    return self.name
end

-- Returns this message's id (each message name has a unique id).
function NetMonitor.CapturedMessage:GetId()
    return self.id
end

-- Returns this message's size in bits. 
-- For incoming messages, this is the amount of bits received.
-- For outgoing messages, this is the amount of bits written.
function NetMonitor.CapturedMessage:GetBits()
    return self.bits
end

-- INTERNAL: you shouldn't use this.
function NetMonitor.CapturedMessage:SetBits(bits)
    self.bits = bits
end

-- Returns the amount of bits that got wasted by not being read for an incoming message.
function NetMonitor.CapturedMessage:GetWastedBits()
    return self.wastedBits
end

-- INTERNAL: you shouldn't use this.
function NetMonitor.CapturedMessage:SetWastedBits(waste)
    self.wastedBits = waste
end

-- Returns the recipients of this message, only valid if this message is outgoing.
function NetMonitor.CapturedMessage:GetRecipients()
    return self.recipients or {}
end

-- INTERNAL: you shouldn't use this.
function NetMonitor.CapturedMessage:SetRecipients(recipients)
    if !self.recipients then self.recipients = recipients end
end

-- Returns the name and id of the sender. On clients, this will be SERVER and -1
function NetMonitor.CapturedMessage:GetSender()
    return self.senderName, self.senderId
end

-- INTERNAL: you shouldn't use this.
function NetMonitor.CapturedMessage:SetSender(client)
    if !client or !isentity(client) and !client:IsPlayer() then
        Error("Invalid client passed as captured message sender")
    end

    self.senderId = client:SteamID64()
    self.senderName = client:Nick()
end

-- Returns this net message's mode.
-- Values to expect are Send, SendToServer, Broadcast, SendPVS, SendPAS or SendOmit.
-- Discarded net messages will have the Discarded mode
-- Received net messages will have the Received mode
function NetMonitor.CapturedMessage:GetMode()
    return self.mode or "Unknown"
end

-- INTERNAL: you shouldn't use this.
function NetMonitor.CapturedMessage:SetMode(mode)
    if !self.mode then
        self.mode = mode
        if mode == "Received" and CLIENT then
            self.senderName = "SERVER"
            self.senderId = -1
        end
    end
end

-- Returns whether or not this message is sent unreliably. Only set in outgoing messages.
function NetMonitor.CapturedMessage:IsUnreliable()
    return self.unreliable
end

-- Returns whether or not this message was received or sent.
function NetMonitor.CapturedMessage:IsReceived()
    return self.mode == "Received"
end

-- Returns true if this message was discarded.
function NetMonitor.CapturedMessage:IsDiscarded()
    return self.mode == "Discarded"
end

-- Returns true if this message was ignored.
function NetMonitor.CapturedMessage:IsIgnored()
    return self.mode == "Ignored"
end

-- Returns the data written to the net message.
function NetMonitor.CapturedMessage:GetData()
    return self.data
end

-- Called if the captured message was sent/received using the deprecated umsg system.
function NetMonitor.CapturedMessage:SetDeprecated()
    self.deprecated = true
end

-- Whether or not this message was sent/received using the deprecated umsg system.
function NetMonitor.CapturedMessage:IsUserMessage()
    return self.deprecated
end

-- Write an angle to the captured message's data.
function NetMonitor.CapturedMessage:WriteAngle(ang)
    self.data[#self.data + 1] = {type = "ANGLE", value = ang}
end

-- Write a bit to the captured message's data.
function NetMonitor.CapturedMessage:WriteBit(inBit)
    self.data[#self.data + 1] = {type = "BIT", value = inBit}
end

-- Write a color to the capture message's data.
function NetMonitor.CapturedMessage:WriteColor(color)
    self.data[#self.data + 1] = {type = "COLOR", value = color}
end

-- Write binary data to the captured message's data.
function NetMonitor.CapturedMessage:WriteData(binaryData, length)
    if length <= 0 then 
        binaryData = ""
    elseif #binaryData > length then
        binaryData = string.sub(binaryData, 1, length)
    end

    self.data[#self.data + 1] = {type = "BINARY", value = binaryData}
end

-- Write a double to the captured message's data.
function NetMonitor.CapturedMessage:WriteDouble(double)
    self.data[#self.data + 1] = {type = "DOUBLE", value = double}
end

-- Write an entity to the captured message's data. This is the entity's unique id.
function NetMonitor.CapturedMessage:WriteEntity(ent)
    self.data[#self.data + 1] = {type = "ENTITY", value = ent:EntIndex()}
end

-- Write a float to the captured message's data.
function NetMonitor.CapturedMessage:WriteFloat(float)
    self.data[#self.data + 1] = {type = "FLOAT", value = float}
end

-- Write an int to the captured message's data.
function NetMonitor.CapturedMessage:WriteInt(int, bits)
    self.data[#self.data + 1] = {type = "INT", value = int}
end

-- Write a matrix to the captured message's data.
function NetMonitor.CapturedMessage:WriteMatrix(matrix)
    self.data[#self.data + 1] = {type = "MATRIX", value = matrix}
end

-- Write a normalized vector to the captured message's data.
function NetMonitor.CapturedMessage:WriteNormal(normal)
    self.data[#self.data + 1] = {type = "NORMAL", value = normal}
end

-- Write a string to the captured message's data.
function NetMonitor.CapturedMessage:WriteString(str)
    self.data[#self.data + 1] = {type = "STRING", value = str}
end

-- Write a table to the captured message's data. 
-- If you do this, you're a bad person. 
function NetMonitor.CapturedMessage:WriteTable(tbl)
    self.data[#self.data + 1] = {type = "TABLE", value = tbl}
end

-- Write a matrix to the captured message's data.
function NetMonitor.CapturedMessage:WriteMatrix(matrix)
    self.data[#self.data + 1] = {type = "MATRIX", value = matrix}
end

-- Write an unsigned int to the captured message's data.
function NetMonitor.CapturedMessage:WriteUInt(uint, bits)
    self.data[#self.data + 1] = {type = "UINT", value = uint}
end

-- Write a vector to the captured message's data.
function NetMonitor.CapturedMessage:WriteVector(vec)
    self.data[#self.data + 1] = {type = "VECTOR", value = vec}
end

-- Write a signed byte (umsg char) to the captured message's data
function NetMonitor.CapturedMessage:WriteChar(char)
    self.data[#self.data + 1] = {type = "CHAR", value = char}
end

-- Write a long to the captured message's data
function NetMonitor.CapturedMessage:WriteLong(long)
    self.data[#self.data + 1] = {type = "LONG", value = long}
end

-- Write a short to the captured message's data
function NetMonitor.CapturedMessage:WriteShort(short)
    self.data[#self.data + 1] = {type = "SHORT", value = short}
end

-- INTERNAL: you shouldn't use this.
function NetMonitor.CapturedMessage:DumpRemainingData(bits)
    -- If a net message wasn't completely read, we'll be able to dump the rest here.
    -- If this occurs, this means you're probably wasting bandwidth.
    if !bits or bits == 0 then return end

    local bitStr = ""
    while bits > 0 do
        bitStr = bitStr .. tostring(net.ReadBit())
        bits = bits - 1
    end

    if bytes and bytes > 0 then
        self.data[#self.data + 1] = {type = "DUMP", value = bitStr}
    end
end

setmetatable(NetMonitor.CapturedMessage, {__call = NetMonitor.CapturedMessage.new})
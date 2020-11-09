AddCSLuaFile()

NetMonitor = NetMonitor or {}
NetMonitor.CurrentMessage = NetMonitor.CurrentMessage or nil
NetMonitor.CurrentMessageFuncInfo = NetMonitor.CurrentMessageFuncInfo or nil
NetMonitor.CurrentMessageCount = 1
NetMonitor.CurrentMessageIncomingLen = 0
NetMonitor.CurrentMessageStartBits = 0

-- Change these flags with info you need, the less you have the less expensive it is.
-- See https://wiki.facepunch.com/gmod/debug.getinfo
NetMonitor.DebugInfoFlags = NetMonitor.DebugInfoFlags or "lS" 
NetMonitor.DebugMode = false

local oldNet = oldNet or {}
local errorColor = Color(255, 90, 90)

local function DebugMsg(msg)
    if NetMonitor.DebugMode then MsgC(Color(0, 102, 255), "NetMonitor: ", msg, "\n") end
end

-- This is called when a net.receive() hook starts a notify that the old one is over, or after a net.receive() hook if we're still reading.
local function FinishReceivedMessage(msg, funcInfo, bitsLeft)
    DebugMsg("Finishing received message")
    if bitsLeft > 0 then
        local bytes = math.ceil(bitsLeft / 8)
        msg:DumpRemainingData(bytes)
        msg:SetWastedBits(bitsLeft)
        hook.Run("OnNetMessageCaptured", msg)
        hook.Run("OnNetMessageDumpedData", msg)
        return
    end

    hook.Run("OnNetMessageCaptured", msg)
end

-- Message receiving/sending function overrides
-- Can't really keep track of the old incoming function since it reads a header that we need to get the message name. 
-- So guess we'll just have to copy the code and just add our stuff that way.
function net.Incoming(len, client)
	local i = net.ReadHeader()
	local strName = util.NetworkIDToString( i )
	
	if ( !strName ) then return end

    DebugMsg("Received net message: " .. strName)

    -- Setup a new captured message to read data into it.
    -- Check that there is no current message left. If there is, this means a network message was started but not sent.
    if NetMonitor.CurrentMessage != nil and !NetMonitor.CurrentMessage:IsReceived() then
        DebugMsg("Already had a net message, discarded.")
        NetMonitor.CurrentMessage:SetMode("Discarded")
        hook.Run("OnNetMessageDiscarded", NetMonitor.CurrentMessage, NetMonitor.CurrentMessageFuncInfo)
        NetMonitor.CurrentMessage = nil
        NetMonitor.CurrentMessageFuncInfo = nil
    end

    NetMonitor.CurrentMessage = NetMonitor.CapturedMessage(strName)
    NetMonitor.CurrentMessage:SetMode("Received")
    NetMonitor.CurrentMessage:SetBits(len - 16)

    if SERVER then NetMonitor.CurrentMessage:SetSender(client) end

	local func = net.Receivers[ strName:lower() ]
	if ( !func ) then 
        DebugMsg("Message has no hooked function.")
        -- Still run the message received hook. However, since no function is there to read anything, we won't see what exactly was sent.
        -- If there's still something to read, we could just dump them into binary data.
        len = len - 16
        local bytes = math.ceil(len / 8)
        if bytes > 0 then
            DebugMsg("Message has bytes left to dump.")
            NetMonitor.CurrentMessage:DumpRemainingData()
            hook.Run("OnNetMessageCaptured", NetMonitor.CurrentMessage)
            hook.Run("OnNetMessageIgnored", NetMonitor.CurrentMessage)
            hook.Run("OnNetMessageDumpedData", NetMonitor.CurrentMessage)
            return
        end

        hook.Run("OnNetMessageCaptured", NetMonitor.CurrentMessage)
        hook.Run("OnNetMessageIgnored", NetMonitor.CurrentMessage)
        NetMonitor.CurrentMessage = nil
        return
    end

    -- len includes the 16 bit int which told us the message name
	len = len - 16

    local currentMessage = NetMonitor.CurrentMessageCount
    local _, bits = net.BytesLeft()
    
    NetMonitor.CurrentMessageIncomingLen = len
    NetMonitor.CurrentMessageStartBits = bits

    DebugMsg("Calling message hook. Len: " .. len)
	func( len, client )
    DebugMsg("Message hook finished!")

    -- If a new message was created by the receive func, don't do anything
    if currentMessage != NetMonitor.CurrentMessageCount then return end

    _, bits = net.BytesLeft()
    local bitsLeft = NetMonitor.CurrentMessageIncomingLen - (NetMonitor.CurrentMessageStartBits - bits)

    FinishReceivedMessage(NetMonitor.CurrentMessage, NetMonitor.CurrentMessageFuncInfo, bitsLeft)
    NetMonitor.CurrentMessage = nil
    NetMonitor.CurrentMessageInfo = nil
    NetMonitor.CurrentMessageCount = NetMonitor.CurrentMessageCount + 1
end

oldNet.Start = oldNet.Start or net.Start
function net.Start(msgName, unreliable)
    unreliable = unreliable or false

    -- If this was called in a receive callback, notify the monitor that the old message is over.
    if NetMonitor.CurrentMessage != nil and NetMonitor.CurrentMessage:IsReceived() then
        DebugMsg("Starting a message while a message is still marked as received, notifying that the message is over.")

        _, bits = net.BytesLeft()
        local bitsLeft = NetMonitor.CurrentMessageIncomingLen - (NetMonitor.CurrentMessageStartBits - bits)
        FinishReceivedMessage(NetMonitor.CurrentMessage, NetMonitor.CurrentMessageFuncInfo, bitsLeft)
        
        NetMonitor.CurrentMessage = nil
        NetMonitor.CurrentMessageFuncInfo = nil
    end

    oldNet.Start(msgName, unreliable) -- This will halt execution on error, so we'll execute it now. 
    NetMonitor.CurrentMessageCount = NetMonitor.CurrentMessageCount + 1

    -- Check if an outgoing captured message is still being captured.
    if NetMonitor.CurrentMessage != nil and !NetMonitor.CurrentMessage:IsReceived() then
        DebugMsg("Started a message while another was already running.")
        hook.Run("OnNetMessageDiscarded", NetMonitor.CurrentMessage, NetMonitor.CurrentMessageFuncInfo)
        NetMonitor.CurrentMessage = nil
        NetMonitor.CurrentMessageFuncInfo = nil
    end

    DebugMsg("Starting a new message!")
    NetMonitor.CurrentMessage = NetMonitor.CapturedMessage(msgName, unreliable)
    NetMonitor.CurrentMessageFuncInfo = debug.getinfo(2, NetMonitor.DebugInfoFlags)
    hook.Run("OnNetMessageStarted", msgName, NetMonitor.CurrentMessageFuncInfo)
end

if SERVER then -- Server only net functions

oldNet.Send = oldNet.Send or net.Send
function net.Send(ply)
    local _, bits = net.BytesWritten()
    oldNet.Send(ply)

    -- That should never happen but sure.
    if !NetMonitor.CurrentMessage then 
        MsgC(errorColor, "A net message was sent, but the net monitor doesn't recall one ever starting.\n")
        return
    end

    NetMonitor.CurrentMessage:SetMode("Send")
    NetMonitor.CurrentMessage:SetBits(bits)

    if isentity(ply) and ply:IsPlayer() then 
        NetMonitor.CurrentMessage:SetRecipients({ply})
    elseif TypeID(ply) == TYPE_RECIPIENTFILTER then
        NetMonitor.CurrentMessage:SetRecipients(ply:GetPlayers())
    elseif istable(ply) then
        NetMonitor.CurrentMessage:SetRecipients(ply)
    end

    DebugMsg("SEND")
    hook.Run("OnNetMessageCaptured", NetMonitor.CurrentMessage, NetMonitor.CurrentMessageFuncInfo)
    NetMonitor.CurrentMessage = nil
    NetMonitor.CurrentMessageFuncInfo = nil
end

oldNet.SendOmit = oldNet.SendOmit or net.SendOmit
function net.SendOmit(ply)
    local _, bits = net.BytesWritten()
    oldNet.SendOmit(ply)

    -- That should never happen but sure.
    if !NetMonitor.CurrentMessage then 
        MsgC(errorColor, "A net message was sent, but the net monitor doesn't recall one ever starting.\n")
        return
    end

    NetMonitor.CurrentMessage:SetMode("SendOmit")
    NetMonitor.CurrentMessage:SetBits(bits)

    -- SendOmit switches to broadcast if the player argument is nil or empty
    if ply and isentity(ply) and ply:IsPlayer() then
        local recipients = player.GetAll()
        table.RemoveByValue(recipients, ply)
        NetMonitor.CurrentMessage:SetRecipients(recipients)
    elseif istable(ply) then
        if #ply == 0 then
            NetMonitor.CurrentMessage:SetMode("Broadcast")
            NetMonitor.CurrentMessage:SetRecipients(player.GetAll())
        else
            local recipients = player.GetAll()
            for _, v in pairs(ply) do table.RemoveByValue(recipients, v) end

            NetMonitor.CurrentMessage:SetRecipients(recipients)
        end
    else
        NetMonitor.CurrentMessage:SetMode("Broadcast")
        NetMonitor.CurrentMessage:SetRecipients(player.GetAll())
    end

    DebugMsg("SENDOMIT")
    hook.Run("OnNetMessageCaptured", NetMonitor.CurrentMessage, NetMonitor.CurrentMessageFuncInfo)
    NetMonitor.CurrentMessage = nil
    NetMonitor.CurrentMessageFuncInfo = nil
end

oldNet.SendPAS = oldNet.SendPAS or net.SendPAS
function net.SendPAS(position)
    local _, bits = net.BytesWritten()
    oldNet.SendPAS(position)

    -- That should never happen but sure.
    if !NetMonitor.CurrentMessage then 
        MsgC(errorColor, "A net message was sent, but the net monitor doesn't recall one ever starting.\n")
        return
    end

    NetMonitor.CurrentMessage:SetMode("SendPAS")
    NetMonitor.CurrentMessage:SetBits(bits)

    local rf = RecipientFilter()
    rf:AddPAS(position)

    NetMonitor.CurrentMessage:SetRecipients(rf:GetPlayers())

    DebugMsg("SENDPAS")
    hook.Run("OnNetMessageCaptured", NetMonitor.CurrentMessage, NetMonitor.CurrentMessageFuncInfo)
    NetMonitor.CurrentMessage = nil
    NetMonitor.CurrentMessageFuncInfo = nil
end

oldNet.SendPVS = oldNet.SendPVS or net.SendPVS
function net.SendPVS(position)
    local _, bits = net.BytesWritten()
    oldNet.SendPVS(position)

    -- That should never happen but sure.
    if !NetMonitor.CurrentMessage then 
        MsgC(errorColor, "A net message was sent, but the net monitor doesn't recall one ever starting.\n")
        return
    end

    NetMonitor.CurrentMessage:SetMode("SendPVS")
    NetMonitor.CurrentMessage:SetBits(bits)

    local rf = RecipientFilter()
    rf:AddPVS(position)

    NetMonitor.CurrentMessage:SetRecipients(rf:GetPlayers())

    DebugMsg("SENDPVS")

    hook.Run("OnNetMessageCaptured", NetMonitor.CurrentMessage, NetMonitor.CurrentMessageFuncInfo)
    NetMonitor.CurrentMessage = nil
    NetMonitor.CurrentMessageFuncInfo = nil
end

oldNet.Broadcast = oldNet.Broadcast or net.Broadcast
function net.Broadcast()
    local _, bits = net.BytesWritten()
    oldNet.Broadcast()

    if !NetMonitor.CurrentMessage then 
        MsgC(errorColor, "A net message was sent, but the net monitor doesn't recall one ever starting.\n")
        return
    end

    NetMonitor.CurrentMessage:SetMode("Broadcast")
    NetMonitor.CurrentMessage:SetBits(bits or 0)
    NetMonitor.CurrentMessage:SetRecipients(player.GetAll())

    DebugMsg("BROADCAST")
    hook.Run("OnNetMessageCaptured", NetMonitor.CurrentMessage, NetMonitor.CurrentMessageFuncInfo)
    NetMonitor.CurrentMessage = nil
    NetMonitor.CurrentMessageFuncInfo = nil
end

end -- Server only net functions

if CLIENT then -- Client only net functions 

oldNet.SendToServer = oldNet.SendToServer or net.SendToServer
function net.SendToServer()
    local _, bits = net.BytesWritten()
    oldNet.SendToServer()

    if !NetMonitor.CurrentMessage then 
        MsgC(errorColor, "A net message was sent, but the net monitor doesn't recall one ever starting.\n")
        return
    end

    NetMonitor.CurrentMessage:SetMode("SendToServer")
    NetMonitor.CurrentMessage:SetBits(bits or 0)

    DebugMsg("SENDTOSERVER")
    hook.Run("OnNetMessageCaptured", NetMonitor.CurrentMessage, NetMonitor.CurrentMessageFuncInfo)
    NetMonitor.CurrentMessage = nil
    NetMonitor.CurrentMessageFuncInfo = nil
end

end -- Client only net functions

-- Now we override write/read functions to feed the data to the captured message.

oldNet.ReadAngle = oldNet.ReadAngle or net.ReadAngle
function net.ReadAngle()
    local ang = oldNet.ReadAngle()
    NetMonitor.CurrentMessage:WriteAngle(ang)
    return ang
end

oldNet.WriteAngle = oldNet.WriteAngle or net.WriteAngle
function net.WriteAngle(ang)
    oldNet.WriteAngle(ang)
    NetMonitor.CurrentMessage:WriteAngle(ang)
end

oldNet.ReadBit = oldNet.ReadBit or net.ReadBit
function net.ReadBit()
    local b = oldNet.ReadBit()
    NetMonitor.CurrentMessage:WriteBit(b)
    return b
end

oldNet.WriteBit = oldNet.WriteBit or net.WriteBit
function net.WriteBit(b)
    oldNet.WriteBit(b)
    NetMonitor.CurrentMessage:WriteBit(b)
end

oldNet.ReadColor = oldNet.ReadColor or net.ReadColor
function net.ReadColor()
    local color = oldNet.ReadColor()
    NetMonitor.CurrentMessage:WriteColor(color)
    return color
end

oldNet.WriteColor = oldNet.WriteColor or net.WriteColor
function net.WriteColor(color)
    oldNet.WriteColor(color)
    NetMonitor.CurrentMessage:WriteColor(color)
end

oldNet.ReadData = oldNet.ReadData or net.ReadData
function net.ReadData(len)
    local data = oldNet.ReadData(len)
    NetMonitor.CurrentMessage:WriteData(data, len)
    return data
end

oldNet.WriteData = oldNet.WriteData or net.WriteData
function net.WriteData(data, len)
    oldNet.WriteData(data, len)
    NetMonitor.CurrentMessage:WriteData(data, len)
end

oldNet.ReadDouble = oldNet.ReadDouble or net.ReadDouble
function net.ReadDouble()
    local double = oldNet.ReadDouble()
    NetMonitor.CurrentMessage:WriteDouble(double)
    return double
end

oldNet.WriteDouble = oldNet.WriteDouble or net.WriteDouble
function net.WriteDouble(double)
    oldNet.WriteDouble(double)
    NetMonitor.CurrentMessage:WriteDouble(double)
end

oldNet.ReadEntity = oldNet.ReadEntity or net.ReadEntity
function net.ReadEntity()
    local ent = oldNet.ReadEntity()
    NetMonitor.CurrentMessage:WriteEntity(ent)
    return ent
end

oldNet.WriteEntity = oldNet.WriteEntity or net.WriteEntity
function net.WriteEntity(ent)
    oldNet.WriteEntity(ent)
    NetMonitor.CurrentMessage:WriteEntity(ent)
end

oldNet.ReadFloat = oldNet.ReadFloat or net.ReadFloat
function net.ReadFloat()
    local float = oldNet.ReadFloat()
    NetMonitor.CurrentMessage:WriteFloat(float)
    return float
end

oldNet.WriteFloat = oldNet.WriteFloat or net.WriteFloat
function net.WriteFloat(float)
    oldNet.WriteFloat(float)
    NetMonitor.CurrentMessage:WriteFloat(float)
end

oldNet.ReadInt = oldNet.ReadInt or net.ReadInt
function net.ReadInt(bits)
    local int = oldNet.ReadInt(bits)
    NetMonitor.CurrentMessage:WriteInt(int, bits)
    return int
end

oldNet.WriteInt = oldNet.WriteInt or net.WriteInt
function net.WriteInt(int, bits)
    oldNet.WriteInt(int, bits)
    NetMonitor.CurrentMessage:WriteInt(int, bits)
end

oldNet.ReadMatrix = oldNet.ReadMatrix or net.ReadMatrix
function net.ReadMatrix()
    local mat = oldNet.ReadMatrix()
    NetMonitor.CurrentMessage:WriteMatrix(mat)
    return mat
end

oldNet.WriteMatrix = oldNet.WriteMatrix or net.WriteMatrix
function net.WriteMatrix(mat)
    oldNet.WriteMatrix(mat)
    NetMonitor.CurrentMessage:WriteMatrix(mat)
end

oldNet.ReadNormal = oldNet.ReadNormal or net.ReadNormal
function net.ReadNormal()
    local normal = oldNet.ReadNormal()
    NetMonitor.CurrentMessage:WriteNormal(normal)
    return normal
end

oldNet.WriteNormal = oldNet.WriteNormal or net.WriteNormal
function net.WriteNormal(normal)
    oldNet.WriteNormal(normal)
    NetMonitor.CurrentMessage:WriteNormal(normal)
end

oldNet.ReadString = oldNet.ReadString or net.ReadString
function net.ReadString()
    local str = oldNet.ReadString()
    NetMonitor.CurrentMessage:WriteString(str)
    return str
end

oldNet.WriteString = oldNet.WriteString or net.WriteString
function net.WriteString(str)
    oldNet.WriteString(str)
    NetMonitor.CurrentMessage:WriteString(str)
end

oldNet.ReadTable = oldNet.ReadTable or net.ReadTable
function net.ReadTable()
    local tbl = oldNet.ReadTable()
    NetMonitor.CurrentMessage:WriteTable(tbl)
    return tbl
end

oldNet.WriteTable = oldNet.WriteTable or net.WriteTable
function net.WriteTable(tbl)
    oldNet.WriteTable(tbl)
    NetMonitor.CurrentMessage:WriteTable(tbl)
end

oldNet.ReadUInt = oldNet.ReadUInt or net.ReadUInt
function net.ReadUInt(bits)
    local uint = oldNet.ReadUInt(bits)
    NetMonitor.CurrentMessage:WriteUInt(uint, bits)
    return uint
end

oldNet.WriteUInt = oldNet.WriteUInt or net.WriteUInt
function net.WriteUInt(uint, bits)
    oldNet.WriteUInt(uint, bits)
    NetMonitor.CurrentMessage:WriteUInt(uint, bits)
end

oldNet.ReadVector = oldNet.ReadVector or net.ReadVector
function net.ReadVector()
    local vec = oldNet.ReadVector()
    NetMonitor.CurrentMessage:WriteVector(vector)
    return vec
end

oldNet.WriteVector = oldNet.WriteVector or net.WriteVector
function net.WriteVector(vector)
    oldNet.WriteVector(vector)
    NetMonitor.CurrentMessage:WriteVector(vector)
end
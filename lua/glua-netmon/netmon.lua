AddCSLuaFile()

NetMonitor = NetMonitor or {}
NetMonitor.Registry = NetMonitor.Registry or {}
NetMonitor.CurrentMessage = NetMonitor.CurrentMessage or nil
NetMonitor.CurrentMessageFuncInfo = NetMonitor.CurrentMessageFuncInfo or nil
NetMonitor.CurrentMessageCount = NetMonitor.CurrentMessageCount or 0
NetMonitor.CurrentMessageIncomingLen = NetMonitor.CurrentMessageIncomingLen or 0
NetMonitor.CurrentMessageStartBits = NetMonitor.CurrentMessageStartBits or 0

NetMonitor.NetOverrides = NetMonitor.NetOverrides or {}
NetMonitor.UserMessageOverrides = NetMonitor.UserMessageOverrides or {}

-- Change these flags with info you need, the less you have the less expensive it is.
-- Please at least keep the 'lS' flags to let the utility work correctly. 
-- See https://wiki.facepunch.com/gmod/debug.getinfo
NetMonitor.DebugInfoFlags = NetMonitor.DebugInfoFlags or "lS" 
NetMonitor.DebugMode = NetMonitor.DebugMode or false

local errorColor = Color(255, 90, 90)

local function DebugMsg(msg)
    if NetMonitor.DebugMode then MsgC(Color(0, 102, 255), "NetMonitor: ", msg, "\n") end
end

-- This is called when a net.receive() hook starts a notify that the old one is over, or after a net.receive() hook if we're still reading.
local function FinishReceivedMessage(msg, funcInfo, bitsLeft)
    DebugMsg("Finishing received message")
    if bitsLeft > 0 and not msg:IsUserMessage() then
        msg:DumpRemainingData(bitsLeft)
        msg:SetWastedBits(bitsLeft)
        hook.Run("OnNetMessageCaptured", msg, funcInfo)
        hook.Run("OnNetMessageDumpedData", msg, funcInfo)
        return
    end

    hook.Run("OnNetMessageCaptured", msg, funcInfo)
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
        if len > 0 then
            DebugMsg("Message has bytes left to dump.")
            NetMonitor.CurrentMessage:DumpRemainingData(len)
            hook.Run("OnNetMessageCaptured", NetMonitor.CurrentMessage, nil)
            hook.Run("OnNetMessageIgnored", NetMonitor.CurrentMessage, nil)
            hook.Run("OnNetMessageDumpedData", NetMonitor.CurrentMessage, nil)
            return
        end

        hook.Run("OnNetMessageCaptured", NetMonitor.CurrentMessage, nil)
        hook.Run("OnNetMessageIgnored", NetMonitor.CurrentMessage, nil)
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

    FinishReceivedMessage(NetMonitor.CurrentMessage, nil, bitsLeft)
    NetMonitor.CurrentMessage = nil
    NetMonitor.CurrentMessageCount = NetMonitor.CurrentMessageCount + 1
end

NetMonitor.UserMessageOverrides.IncomingMessage = NetMonitor.UserMessageOverrides.IncomingMessage or usermessage.IncomingMessage
function usermessage.IncomingMessage(name, msg)
    -- Check that there is no current message left. If there is, this means a network message was started but not sent.
    if NetMonitor.CurrentMessage != nil and !NetMonitor.CurrentMessage:IsReceived() then
        DebugMsg("Already had a net message, discarded.")
        NetMonitor.CurrentMessage:SetMode("Discarded")
        hook.Run("OnNetMessageDiscarded", NetMonitor.CurrentMessage, NetMonitor.CurrentMessageFuncInfo)
        NetMonitor.CurrentMessage = nil
        NetMonitor.CurrentMessageFuncInfo = nil
    end

    -- Prepare the message for reading. 
    NetMonitor.CurrentMessage = NetMonitor.CapturedMessage(name)
    NetMonitor.CurrentMessage:SetMode("Received")
    NetMonitor.CurrentMessage:SetDeprecated()

    local currentMessage = NetMonitor.CurrentMessageCount

    NetMonitor.UserMessageOverrides.IncomingMessage(name, msg)

    if currentMessage != NetMonitor.CurrentMessageCount then return end
    
    FinishReceivedMessage(NetMonitor.CurrentMessage, nil, 0)
    NetMonitor.CurrentMessageCount = NetMonitor.CurrentMessageCount + 1
    NetMonitor.CurrentMessage = nil
end

NetMonitor.NetOverrides.Receive = NetMonitor.NetOverrides.Receive or net.Receive
function net.Receive(messageName, callback)
    NetMonitor.NetOverrides.Receive(messageName, callback)

    local info = debug.getinfo(2, NetMonitor.DebugInfoFlags)
    if info.short_src and info.short_src != "lua_run" and info.short_src != "lua_run_cl" then
        NetMonitor.Registry.RegisterReceiveFile(messageName, info.short_src)
    end
end

NetMonitor.NetOverrides.Start = NetMonitor.NetOverrides.Start or net.Start
function net.Start(msgName, unreliable)
    unreliable = unreliable or false

    -- If this was called in a receive callback, notify the monitor that the old message is over.
    if NetMonitor.CurrentMessage != nil and NetMonitor.CurrentMessage:IsReceived() then
        if not NetMonitor.CurrentMessage:IsUserMessage() then
            local _, bits = net.BytesLeft() 
            local bitsLeft = bits and NetMonitor.CurrentMessageIncomingLen - (NetMonitor.CurrentMessageStartBits - bits) or 0
            FinishReceivedMessage(NetMonitor.CurrentMessage, NetMonitor.CurrentMessageFuncInfo, bitsLeft)
        else
            FinishReceivedMessage(NetMonitor.CurrentMessage, NetMonitor.CurrentMessageFuncInfo, 0)
        end

        NetMonitor.CurrentMessage = nil
        NetMonitor.CurrentMessageFuncInfo = nil
    end

    NetMonitor.NetOverrides.Start(msgName, unreliable) -- This will halt execution on error, so we'll execute it now. 
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

-- Deprecated umsg library.
-- Seriously, please stop using that pile of garbage.
NetMonitor.UserMessageOverrides.Start = NetMonitor.UserMessageOverrides.Start or umsg.Start
function umsg.Start(name, filter)
    if NetMonitor.CurrentMessage != nil and NetMonitor.CurrentMessage:IsReceived() then
        if not NetMonitor.CurrentMessage:IsUserMessage() then
            local _, bits = net.BytesLeft() 
            local bitsLeft = NetMonitor.CurrentMessageIncomingLen - (NetMonitor.CurrentMessageStartBits - bits)
            FinishReceivedMessage(NetMonitor.CurrentMessage, NetMonitor.CurrentMessageFuncInfo, bitsLeft)
        else
            FinishReceivedMessage(NetMonitor.CurrentMessage, NetMonitor.CurrentMessageFuncInfo, 0)
        end

        NetMonitor.CurrentMessage = nil
        NetMonitor.CurrentMessageFuncInfo = nil
    end

    NetMonitor.UserMessageOverrides.Start(name, filter)
    NetMonitor.CurrentMessageCount = NetMonitor.CurrentMessageCount + 1

    if NetMonitor.CurrentMessage != nil and !NetMonitor.CurrentMessage:IsReceived() then
        DebugMsg("Started a message while another was already running.")
        hook.Run("OnNetMessageDiscarded", NetMonitor.CurrentMessage, NetMonitor.CurrentMessageFuncInfo)
        NetMonitor.CurrentMessage = nil
        NetMonitor.CurrentMessageFuncInfo = nil
    end

    -- Create a "deprecated" message for umsg.
    NetMonitor.CurrentMessage = NetMonitor.CapturedMessage(name)
    NetMonitor.CurrentMessage:SetDeprecated()
    NetMonitor.CurrentMessageFuncInfo = debug.getinfo(2, NetMonitor.DebugInfoFlags)

    -- Since recipients are set here, add them to the message now.
    if not filter then
        NetMonitor.CurrentMessage:SetRecipients(player.GetAll())
    elseif isentity(filter) and filter:IsPlayer() then
        NetMonitor.CurrentMessage:SetRecipients({filter})
    elseif TypeID(filter) == TYPE_RECIPIENTFILTER then
        NetMonitor.CurrentMessage:SetRecipients(filter:GetPlayers())
    end
    
    hook.Run("OnNetMessageStarted", name, NetMonitor.CurrentMessageFuncInfo)
end

NetMonitor.UserMessageOverrides.End = NetMonitor.UserMessageOverrides.End or umsg.End
function umsg.End()
    NetMonitor.UserMessageOverrides.End()

    NetMonitor.CurrentMessage:SetMode("Deprecated Send")
    hook.Run("OnNetMessageCaptured", NetMonitor.CurrentMessage, NetMonitor.CurrentMessageFuncInfo)
    NetMonitor.CurrentMessage = nil
    NetMonitor.CurrentMessageFuncInfo = nil
end

NetMonitor.NetOverrides.Send = NetMonitor.NetOverrides.Send or net.Send
function net.Send(ply)
    local _, bits = net.BytesWritten()
    NetMonitor.NetOverrides.Send(ply)

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

NetMonitor.NetOverrides.SendOmit = NetMonitor.NetOverrides.SendOmit or net.SendOmit
function net.SendOmit(ply)
    local _, bits = net.BytesWritten()
    NetMonitor.NetOverrides.SendOmit(ply)

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

NetMonitor.NetOverrides.SendPAS = NetMonitor.NetOverrides.SendPAS or net.SendPAS
function net.SendPAS(position)
    NetMonitor.NetOverrides.SendPAS(position)

    -- That should never happen but sure.
    if !NetMonitor.CurrentMessage then 
        MsgC(errorColor, "A net message was sent, but the net monitor doesn't recall one ever starting.\n")
        return
    end

    local _, bits = net.BytesWritten()
    NetMonitor.CurrentMessage:SetMode("SendPAS")
    NetMonitor.CurrentMessage:SetBits(bits)

    -- Use a recipient filter to find all players that are in the PAS.
    local rf = RecipientFilter()
    rf:AddPAS(position)

    NetMonitor.CurrentMessage:SetRecipients(rf:GetPlayers())

    DebugMsg("SENDPAS")
    hook.Run("OnNetMessageCaptured", NetMonitor.CurrentMessage, NetMonitor.CurrentMessageFuncInfo)
    NetMonitor.CurrentMessage = nil
    NetMonitor.CurrentMessageFuncInfo = nil
end

NetMonitor.NetOverrides.SendPVS = NetMonitor.NetOverrides.SendPVS or net.SendPVS
function net.SendPVS(position)
    NetMonitor.NetOverrides.SendPVS(position)

    -- That should never happen but sure.
    if !NetMonitor.CurrentMessage then 
        MsgC(errorColor, "A net message was sent, but the net monitor doesn't recall one ever starting.\n")
        return
    end

    local _, bits = net.BytesWritten()
    NetMonitor.CurrentMessage:SetMode("SendPVS")
    NetMonitor.CurrentMessage:SetBits(bits)

    -- Use a recipient filter to find all players that are in the PVS.
    local rf = RecipientFilter()
    rf:AddPVS(position)

    NetMonitor.CurrentMessage:SetRecipients(rf:GetPlayers())

    DebugMsg("SENDPVS")

    hook.Run("OnNetMessageCaptured", NetMonitor.CurrentMessage, NetMonitor.CurrentMessageFuncInfo)
    NetMonitor.CurrentMessage = nil
    NetMonitor.CurrentMessageFuncInfo = nil
end

NetMonitor.NetOverrides.Broadcast = NetMonitor.NetOverrides.Broadcast or net.Broadcast
function net.Broadcast()
    NetMonitor.NetOverrides.Broadcast()

    if !NetMonitor.CurrentMessage then 
        MsgC(errorColor, "A net message was sent, but the net monitor doesn't recall one ever starting.\n")
        return
    end

    local _, bits = net.BytesWritten()
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

NetMonitor.NetOverrides.SendToServer = NetMonitor.NetOverrides.SendToServer or net.SendToServer
function net.SendToServer()
    local _, bits = net.BytesWritten()
    NetMonitor.NetOverrides.SendToServer()

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

NetMonitor.NetOverrides.ReadAngle = NetMonitor.NetOverrides.ReadAngle or net.ReadAngle
function net.ReadAngle()
    local ang = NetMonitor.NetOverrides.ReadAngle()
    NetMonitor.CurrentMessage:WriteAngle(ang)
    return ang
end

NetMonitor.NetOverrides.WriteAngle = NetMonitor.NetOverrides.WriteAngle or net.WriteAngle
function net.WriteAngle(ang)
    NetMonitor.NetOverrides.WriteAngle(ang)
    NetMonitor.CurrentMessage:WriteAngle(ang)
end

NetMonitor.NetOverrides.ReadBit = NetMonitor.NetOverrides.ReadBit or net.ReadBit
function net.ReadBit()
    local b = NetMonitor.NetOverrides.ReadBit()
    NetMonitor.CurrentMessage:WriteBit(b)
    return b
end

NetMonitor.NetOverrides.WriteBit = NetMonitor.NetOverrides.WriteBit or net.WriteBit
function net.WriteBit(b)
    NetMonitor.NetOverrides.WriteBit(b)
    NetMonitor.CurrentMessage:WriteBit(b and 1 or 0)
end

NetMonitor.NetOverrides.ReadColor = NetMonitor.NetOverrides.ReadColor or net.ReadColor
function net.ReadColor()
    local color = NetMonitor.NetOverrides.ReadColor()
    NetMonitor.CurrentMessage:WriteColor(color)
    return color
end

NetMonitor.NetOverrides.WriteColor = NetMonitor.NetOverrides.WriteColor or net.WriteColor
function net.WriteColor(color)
    NetMonitor.NetOverrides.WriteColor(color)
    NetMonitor.CurrentMessage:WriteColor(color)
end

NetMonitor.NetOverrides.ReadData = NetMonitor.NetOverrides.ReadData or net.ReadData
function net.ReadData(len)
    local data = NetMonitor.NetOverrides.ReadData(len)
    NetMonitor.CurrentMessage:WriteData(data, len)
    return data
end

NetMonitor.NetOverrides.WriteData = NetMonitor.NetOverrides.WriteData or net.WriteData
function net.WriteData(data, len)
    NetMonitor.NetOverrides.WriteData(data, len)
    NetMonitor.CurrentMessage:WriteData(data, len)
end

NetMonitor.NetOverrides.ReadDouble = NetMonitor.NetOverrides.ReadDouble or net.ReadDouble
function net.ReadDouble()
    local double = NetMonitor.NetOverrides.ReadDouble()
    NetMonitor.CurrentMessage:WriteDouble(double)
    return double
end

NetMonitor.NetOverrides.WriteDouble = NetMonitor.NetOverrides.WriteDouble or net.WriteDouble
function net.WriteDouble(double)
    NetMonitor.NetOverrides.WriteDouble(double)
    NetMonitor.CurrentMessage:WriteDouble(double)
end

NetMonitor.NetOverrides.ReadEntity = NetMonitor.NetOverrides.ReadEntity or net.ReadEntity
function net.ReadEntity()
    local ent = NetMonitor.NetOverrides.ReadEntity()
    NetMonitor.CurrentMessage:WriteEntity(ent)
    return ent
end

NetMonitor.NetOverrides.WriteEntity = NetMonitor.NetOverrides.WriteEntity or net.WriteEntity
function net.WriteEntity(ent)
    NetMonitor.NetOverrides.WriteEntity(ent)
    NetMonitor.CurrentMessage:WriteEntity(ent)
end

NetMonitor.NetOverrides.ReadFloat = NetMonitor.NetOverrides.ReadFloat or net.ReadFloat
function net.ReadFloat()
    local float = NetMonitor.NetOverrides.ReadFloat()
    NetMonitor.CurrentMessage:WriteFloat(float)
    return float
end

NetMonitor.NetOverrides.WriteFloat = NetMonitor.NetOverrides.WriteFloat or net.WriteFloat
function net.WriteFloat(float)
    NetMonitor.NetOverrides.WriteFloat(float)
    NetMonitor.CurrentMessage:WriteFloat(float)
end

NetMonitor.NetOverrides.ReadInt = NetMonitor.NetOverrides.ReadInt or net.ReadInt
function net.ReadInt(bits)
    local int = NetMonitor.NetOverrides.ReadInt(bits)
    NetMonitor.CurrentMessage:WriteInt(int, bits)
    return int
end

NetMonitor.NetOverrides.WriteInt = NetMonitor.NetOverrides.WriteInt or net.WriteInt
function net.WriteInt(int, bits)
    NetMonitor.NetOverrides.WriteInt(int, bits)
    NetMonitor.CurrentMessage:WriteInt(int, bits)
end

NetMonitor.NetOverrides.ReadMatrix = NetMonitor.NetOverrides.ReadMatrix or net.ReadMatrix
function net.ReadMatrix()
    local mat = NetMonitor.NetOverrides.ReadMatrix()
    NetMonitor.CurrentMessage:WriteMatrix(mat)
    return mat
end

NetMonitor.NetOverrides.WriteMatrix = NetMonitor.NetOverrides.WriteMatrix or net.WriteMatrix
function net.WriteMatrix(mat)
    NetMonitor.NetOverrides.WriteMatrix(mat)
    NetMonitor.CurrentMessage:WriteMatrix(mat)
end

NetMonitor.NetOverrides.ReadNormal = NetMonitor.NetOverrides.ReadNormal or net.ReadNormal
function net.ReadNormal()
    local normal = NetMonitor.NetOverrides.ReadNormal()
    NetMonitor.CurrentMessage:WriteNormal(normal)
    return normal
end

NetMonitor.NetOverrides.WriteNormal = NetMonitor.NetOverrides.WriteNormal or net.WriteNormal
function net.WriteNormal(normal)
    NetMonitor.NetOverrides.WriteNormal(normal)
    NetMonitor.CurrentMessage:WriteNormal(normal)
end

NetMonitor.NetOverrides.ReadString = NetMonitor.NetOverrides.ReadString or net.ReadString
function net.ReadString()
    local str = NetMonitor.NetOverrides.ReadString()
    NetMonitor.CurrentMessage:WriteString(str)
    return str
end

NetMonitor.NetOverrides.WriteString = NetMonitor.NetOverrides.WriteString or net.WriteString
function net.WriteString(str)
    NetMonitor.NetOverrides.WriteString(str)
    NetMonitor.CurrentMessage:WriteString(str)
end

NetMonitor.NetOverrides.ReadTable = NetMonitor.NetOverrides.ReadTable or net.ReadTable
function net.ReadTable()
    local tbl = NetMonitor.NetOverrides.ReadTable()
    NetMonitor.CurrentMessage:WriteTable(tbl)
    return tbl
end

NetMonitor.NetOverrides.WriteTable = NetMonitor.NetOverrides.WriteTable or net.WriteTable
function net.WriteTable(tbl)
    NetMonitor.NetOverrides.WriteTable(tbl)
    NetMonitor.CurrentMessage:WriteTable(tbl)
end

NetMonitor.NetOverrides.ReadUInt = NetMonitor.NetOverrides.ReadUInt or net.ReadUInt
function net.ReadUInt(bits)
    local uint = NetMonitor.NetOverrides.ReadUInt(bits)
    NetMonitor.CurrentMessage:WriteUInt(uint, bits)
    return uint
end

NetMonitor.NetOverrides.WriteUInt = NetMonitor.NetOverrides.WriteUInt or net.WriteUInt
function net.WriteUInt(uint, bits)
    NetMonitor.NetOverrides.WriteUInt(uint, bits)
    NetMonitor.CurrentMessage:WriteUInt(uint, bits)
end

NetMonitor.NetOverrides.ReadVector = NetMonitor.NetOverrides.ReadVector or net.ReadVector
function net.ReadVector()
    local vec = NetMonitor.NetOverrides.ReadVector()
    NetMonitor.CurrentMessage:WriteVector(vector)
    return vec
end

NetMonitor.NetOverrides.WriteVector = NetMonitor.NetOverrides.WriteVector or net.WriteVector
function net.WriteVector(vector)
    NetMonitor.NetOverrides.WriteVector(vector)
    NetMonitor.CurrentMessage:WriteVector(vector)
end

-- UserMessage read/write functions are server only.
if SERVER then

NetMonitor.UserMessageOverrides.Angle = NetMonitor.UserMessageOverrides.Angle or umsg.Angle
function umsg.Angle(ang)
    NetMonitor.UserMessageOverrides.Angle(ang)
    NetMonitor.CurrentMessage:WriteAngle(ang)
end

NetMonitor.UserMessageOverrides.Bool = NetMonitor.UserMessageOverrides.Bool or umsg.Bool
function umsg.Bool(bool)
    NetMonitor.UserMessageOverrides.Bool(bool)
    NetMonitor.CurrentMessage:WriteBit(bool and 1 or 0)
end

NetMonitor.UserMessageOverrides.Char = NetMonitor.UserMessageOverrides.Char or umsg.Char
function umsg.Char(char)
    NetMonitor.UserMessageOverrides.Char(char)
    NetMonitor.CurrentMessage:WriteChar(char)
end

NetMonitor.UserMessageOverrides.Entity = NetMonitor.UserMessageOverrides.Entity or umsg.Entity
function umsg.Entity(ent)
    NetMonitor.UserMessageOverrides.Entity(ent)
    NetMonitor.CurrentMessage:WriteEntity(ent)
end

NetMonitor.UserMessageOverrides.Float = NetMonitor.UserMessageOverrides.Float or umsg.Float
function umsg.Float(float)
    NetMonitor.UserMessageOverrides.Float(float)
    NetMonitor.CurrentMessage:WriteFloat(float)
end

NetMonitor.UserMessageOverrides.Long = NetMonitor.UserMessageOverrides.Long or umsg.Long
function umsg.Long(long)
    NetMonitor.UserMessageOverrides.Long(long)
    NetMonitor.CurrentMessage:WriteLong(long)
end

NetMonitor.UserMessageOverrides.Short = NetMonitor.UserMessageOverrides.Short or umsg.Short
function umsg.Short(short)
    NetMonitor.UserMessageOverrides.Short(short)
    NetMonitor.CurrentMessage:WriteShort(short)
end

NetMonitor.UserMessageOverrides.String = NetMonitor.UserMessageOverrides.String or umsg.String
function umsg.String(str)
    NetMonitor.UserMessageOverrides.String(str)
    NetMonitor.CurrentMessage:WriteString(str)
end

NetMonitor.UserMessageOverrides.Vector = NetMonitor.UserMessageOverrides.Vector or umsg.Vector
function umsg.Vector(vec)
    NetMonitor.UserMessageOverrides.Vector(vec)
    NetMonitor.CurrentMessage:WriteVector(vec)
end

NetMonitor.UserMessageOverrides.VectorNormal = NetMonitor.UserMessageOverrides.VectorNormal or umsg.VectorNormal
function umsg.VectorNormal(vec)
    NetMonitor.UserMessageOverrides.VectorNormal(vec)
    NetMonitor.CurrentMessage:WriteNormal(vec)
end

end -- Usermessage Server functions

-- Usermessage client-only read functions.
if CLIENT then 

local bf_read = FindMetaTable("bf_read")

NetMonitor.UserMessageOverrides.ReadAngle = NetMonitor.UserMessageOverrides.ReadAngle or bf_read.ReadAngle
function bf_read:ReadAngle()
    local ang = NetMonitor.UserMessageOverrides.ReadAngle(self)
    NetMonitor.CurrentMessage:WriteAngle(ang)
    return ang
end

NetMonitor.UserMessageOverrides.ReadBool = NetMonitor.UserMessageOverrides.ReadBool or bf_read.ReadBool
function bf_read:ReadBool()
    local bool = NetMonitor.UserMessageOverrides.ReadBool(self)
    NetMonitor.CurrentMessage:WriteBool(bool)
    return bool
end

NetMonitor.UserMessageOverrides.ReadChar = NetMonitor.UserMessageOverrides.ReadChar or bf_read.ReadChar
function bf_read:ReadChar()
    local char = NetMonitor.UserMessageOverrides.ReadChar(self)
    NetMonitor.CurrentMessage:WriteChar(char)
    return char
end

NetMonitor.UserMessageOverrides.ReadEntity = NetMonitor.UserMessageOverrides.ReadEntity or bf_read.ReadEntity
function bf_read:ReadEntity()
    local ent = NetMonitor.UserMessageOverrides.ReadEntity(self)
    NetMonitor.CurrentMessage:WriteEntity(ent)
    return ent
end

NetMonitor.UserMessageOverrides.ReadFloat = NetMonitor.UserMessageOverrides.ReadFloat or bf_read.ReadFloat
function bf_read:ReadFloat()
    local float = NetMonitor.UserMessageOverrides.ReadFloat(self)
    NetMonitor.CurrentMessage:WriteFloat(float)
    return float
end

NetMonitor.UserMessageOverrides.ReadLong = NetMonitor.UserMessageOverrides.ReadLong or bf_read.ReadLong
function bf_read:ReadLong()
    local long = NetMonitor.UserMessageOverrides.ReadLong(self)
    NetMonitor.CurrentMessage:WriteLong(long)
    return long
end

NetMonitor.UserMessageOverrides.ReadShort = NetMonitor.UserMessageOverrides.ReadShort or bf_read.ReadShort
function bf_read:ReadShort()
    local short = NetMonitor.UserMessageOverrides.ReadShort(self)
    NetMonitor.CurrentMessage:WriteShort(short)
    return short
end

NetMonitor.UserMessageOverrides.ReadString = NetMonitor.UserMessageOverrides.ReadString or bf_read.ReadString
function bf_read:ReadString()
    local str = NetMonitor.UserMessageOverrides.ReadString(self)
    NetMonitor.CurrentMessage:WriteString(str)
    return str
end

NetMonitor.UserMessageOverrides.ReadVector = NetMonitor.UserMessageOverrides.ReadVector or bf_read.ReadVector
function bf_read:ReadVector()
    local vec = NetMonitor.UserMessageOverrides.ReadVector(self)
    NetMonitor.CurrentMessage:WriteVector(vec)
    return vec
end

NetMonitor.UserMessageOverrides.ReadVectorNormal = NetMonitor.UserMessageOverrides.ReadVectorNormal or bf_read.ReadVectorNormal
function bf_read:ReadVectorNormal()
    local vec = NetMonitor.UserMessageOverrides.ReadVectorNormal(self)
    NetMonitor.CurrentMessage:WriteVector(vec)
    return vec
end

end -- Usermessage client-only read functions. 

MsgC(Color(0, 255, 0), "NetMonitor: Hooked to the net and umsg libraries.", "\n")
AddCSLuaFile()

NetMonitor = NetMonitor or {}

NetMonitor.BinaryChunk = {}
NetMonitor.BinaryChunk.__index = NetMonitor.BinaryChunk

function NetMonitor.BinaryChunk:new(chunkNum, chunkAmount, chunk)
    local tbl = 
    {
        id = chunkNum, 
        amount = chunkAmount,
        len = #chunk,
        data = chunk
    }

    setmetatable(tbl, NetMonitor.BinaryChunk)
    return tbl
end

function NetMonitor.BinaryChunk:GetId()
    return self.id
end

function NetMonitor.BinaryChunk:GetAmount()
    return self.amount
end

function NetMonitor.BinaryChunk:GetData()
    return self.data
end

function NetMonitor.BinaryChunk:GetLength()
    return self.len
end

function net.WriteBinaryChunk(chunk)
    if getmetatable(chunk) != NetMonitor.BinaryChunk then
        Error("Cannot write invalid chunk, expected BinaryChunk, got: " .. chunk or "nil")
        return
    end

    net.WriteUInt(chunk:GetId(), 16)
    net.WriteUInt(chunk:GetAmount(), 16)
    net.WriteUInt(chunk:GetLength(), 16)
    net.WriteData(chunk:GetData(), chunk:GetLength())
end

function net.ReadBinaryChunk()
    local id = net.ReadUInt(16)
    local amount = net.ReadUInt(16)
    local len = net.ReadUInt(16)
    local dat = net.ReadData(len)

    return NetMonitor.BinaryChunk(id, amount, dat)
end

setmetatable(NetMonitor.BinaryChunk, {__call = NetMonitor.BinaryChunk.new})
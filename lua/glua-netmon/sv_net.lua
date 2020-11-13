NetMonitor = NetMonitor or {}
NetMonitor.Networking = NetMonitor.Networking or {}

util.AddNetworkString("Netmon.RequestInterfacePermission")
util.AddNetworkString("Netmon.GiveInterfacePermission")
util.AddNetworkString("Netmon.RequestRegistry")
util.AddNetworkString("Netmon.SendRegistryChunk")

local function PlayerHasPermission(ply)
    return NetMonitor.Config.AllowedUsergroups[ply:GetUserGroup()] or NetMonitor.Config.AllowedSteamIDs[ply:SteamID64()]
end

local function PlayerSay(ply, text)
    if text:lower() == NetMonitor.Config.InterfaceCommand then
        local hasPermission = PlayerHasPermission(ply)
        local isServerHost = ply:IsListenServerHost()

        net.Start("Netmon.GiveInterfacePermission")
            net.WriteBool(hasPermission)
            net.WriteBool(isServerHost)
        net.Send(ply)
        return ""
    end
end

hook.Add("PlayerSay", "NoDisplayingNetmonCommand", PlayerSay)

local function ReceiveInterfaceRequest(len, ply)
    local hasPermission = PlayerHasPermission(ply)
    local isServerHost = ply:IsListenServerHost()

    net.Start("Netmon.GiveInterfacePermission")
        net.WriteBool(hasPermission)
        net.WriteBool(isServerHost)
    net.Send(ply)
end

net.Receive("Netmon.RequestInterfacePermission", ReceiveInterfaceRequest)

local function RequestRegistry(len, ply)
    -- Players without permission aren't supposed to ever send that string, they can heck off.
    if not PlayerHasPermission(ply) then
        ply:Kick("NetMonitor: Unauthorized usage of network string.")
        return
    end

    MsgC(Color(0, 255, 0), "NetMonitor: Player '", ply:Nick(), "' sent a request for the server's registry.", "\n")

    local chunks = NetMonitor.Registry.BuildRegistryChunks()
    for _, chunk in ipairs(chunks) do
        net.Start("Netmon.SendRegistryChunk")
            net.WriteBinaryChunk(chunk)
        net.Send(ply)
    end
end

net.Receive("Netmon.RequestRegistry", RequestRegistry)
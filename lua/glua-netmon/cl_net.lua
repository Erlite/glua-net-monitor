NetMonitor = NetMonitor or {}
NetMonitor.Networking = NetMonitor.Networking or {}
NetMonitor.Networking.IsHost = NetMonitor.Networking.IsHost or false
NetMonitor.Networking.Authed = NetMonitor.Networking.Authed or false

NetMonitor.Networking.RegistryChunks = NetMonitor.Networking.RegistryChunks or {}

local function ReceiveInterfacePermission(len)
    NetMonitor.Networking.Authed = net.ReadBool()
    NetMonitor.Networking.IsHost = net.ReadBool()

    if not NetMonitor.Networking.Authed then
        NetMonitor.Utils.ChatError("Permission denied!")
        return
    end

    NetMonitor.Interface.Open()
end

net.Receive("Netmon.GiveInterfacePermission", ReceiveInterfacePermission)

local lastRequest = nil

local function RequestInterfacePermission()
    if NetMonitor.Interface.Main then return end

    if lastRequest and CurTime() - lastRequest < 10 then return end
    lastRequest = CurTime()
    
    net.Start("Netmon.RequestInterfacePermission")
    net.SendToServer()
end

concommand.Add("netmon_menu", RequestInterfacePermission, nil, "Opens the network monitor interface.")

local function ReceiveRegistryChunk(len)
    local chunk = net.ReadBinaryChunk()
    NetMonitor.Networking.RegistryChunks[ #NetMonitor.Networking.RegistryChunks + 1 ] = chunk
    if chunk:GetId() == chunk:GetAmount() then
        NetMonitor.Registry.UpdateFromChunks(NetMonitor.Networking.RegistryChunks)
        NetMonitor.Registry.RegistryChunks = {}

        if NetMonitor.Interface.RegistrySyncButton then
            NetMonitor.Interface.RegistrySyncButton:SetEnabled(true)
            NetMonitor.Interface.StatusLabel:SetText("NetMonitor: Synchronized registry")
            NetMonitor.Interface.StatusBar:SetFraction( 1 )
        end
    else
        if NetMonitor.Interface.StatusBar then
            NetMonitor.Interface.StatusBar:SetFraction( 0.6 )
        end
    end
end

net.Receive("Netmon.SendRegistryChunk", ReceiveRegistryChunk)

function NetMonitor.Networking.RequestRegistry()
    net.Start("Netmon.RequestRegistry")
    net.SendToServer()
end
-- Some keys here may also be in the client config, so that you can have different options whether it's clientside or serverside. 

NetMonitor = NetMonitor or {}
NetMonitor.Config = NetMonitor.Config or {}

-- List of SteamID64s that are allowed to access the net monitor interface and data.
NetMonitor.Config.AllowedSteamIDs = 
{
    ["76561198076161102"] = true,
}

-- List of usergroups that are allowed to access the net monitor interface and data.
NetMonitor.Config.AllowedUsergroups =
{
    ["superadmin"] = true,
    ["developer"] = true,
}

-- If true, the net monitor will automatically grab all gamemode files and register them.
NetMonitor.Config.AutoRegisterGamemodeFiles = true

-- If true, the net monitor will automatically grab all addon files and register them.
-- This will take quite a bit of memory since it'll keep track of all lua files in the garrysmod/addons folder.
-- Workshop addons cannot be registered.
NetMonitor.Config.AutoRegisterAddonFiles = true

-- If true, only addons that are registered in the NetMonitor.Registry will be monitored.
NetMonitor.Config.OnlyMonitorRegisteredAddons = false

-- The command to open the netmonitor interface.
NetMonitor.Config.InterfaceCommand = "!netmon"

MsgC(Color(0, 255, 0), "NetMonitor: Loaded server configuration.", "\n")
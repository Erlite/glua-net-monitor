-- Some keys here may also be in the client config, so that you can have different options whether it's clientside or serverside. 

NetMonitor = NetMonitor or {}
NetMonitor.Config = NetMonitor.Config or {}

-- List of SteamID64s that are allowed to access the net monitor interface and data.
NetMonitor.Config.AllowedSteamIDs = 
{
    ["7656119XXXXXXXXX"] = true,
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
NetMonitor.Config.AutoRegisterAddonFiles = false

-- If true, only addons that are registered in the NetMonitor.Registry will be monitored.
NetMonitor.Config.OnlyMonitorRegisteredAddons = false
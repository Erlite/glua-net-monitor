-- Some keys here may also be in the server config, so that you can have different options whether it's clientside or serverside. 

NetMonitor = NetMonitor or {}
NetMonitor.Config = NetMonitor.Config or {}

-- If true, only addons that registered themselves using the netmon-addon-autoreg.lua utility will be monitored.
NetMonitor.Config.OnlyMonitorRegisteredAddons = false

-- If true, the net monitor will automatically grab all gamemode files and register them.
NetMonitor.Config.AutoRegisterGamemodeFiles = true

-- If true, the net monitor will automatically grab all addon files and register them.
-- This will take quite a bit of memory since it'll keep track of all lua files in the garrysmod/addons folder.
-- Workshop addons cannot be registered.
NetMonitor.Config.AutoRegisterAddonFiles = false
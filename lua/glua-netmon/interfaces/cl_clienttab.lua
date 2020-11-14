NetMonitor = NetMonitor or {}
NetMonitor.Interface = NetMonitor.Interface or {}
NetMonitor.Interface.Client = NetMonitor.Interface.Client or {}


NetMonitor.Interface.Client.Main = NetMonitor.Interface.Client.Main or nil

function NetMonitor.Interface.Client.Create(parent)
    local main = vgui.Create( "DPropertySheet", parent)
    main:Dock( FILL )
    main:AddSheet("Captures", vgui.Create( "DPanel", main ), "icon16/disk_multiple.png")
    main:AddSheet("Filters", vgui.Create( "DPanel", main ), "icon16/wrench_orange.png")
    main:AddSheet("Stats", vgui.Create( "DPanel", main ), "icon16/chart_line.png")
    main:AddSheet("Messages", vgui.Create( "DPanel", main ), "icon16/transmit.png")

    return main
end
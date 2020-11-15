NetMonitor = NetMonitor or {}
NetMonitor.Interface = NetMonitor.Interface or {}

NetMonitor.Interface.Client = NetMonitor.Interface.Client or {}
NetMonitor.Interface.Client.Main = NetMonitor.Interface.Client.Main or nil

NetMonitor.Interface.Client.Captures = NetMonitor.Interface.Client.Captures or {}
NetMonitor.Interface.Client.Captures.Main = NetMonitor.Interface.Client.Captures.Main or nil

function NetMonitor.Interface.Client.Create(parent)
    local main = vgui.Create( "DPropertySheet", parent)
    main:Dock( FILL )
    main:AddSheet("Captures", NetMonitor.Interface.Client.CreateCapturesTab(main), "icon16/disk_multiple.png")
    main:AddSheet("Filters", vgui.Create( "DPanel", main ), "icon16/wrench_orange.png")
    main:AddSheet("Stats", vgui.Create( "DPanel", main ), "icon16/chart_line.png")
    main:AddSheet("Messages", vgui.Create( "DPanel", main ), "icon16/transmit.png")

    return main
end

function NetMonitor.Interface.Client.CreateCapturesTab(parent)
    local captures = vgui.Create( "DPanel", parent)

    local captureList = vgui.Create( "DListView", captures)
    captureList:Dock( FILL )
    captureList:DockMargin( 8, 8, 8, 32 )
    captureList:AddColumn( "Name" )
    captureList:AddColumn( "Date" )
    captureList:AddColumn( "Size" )

    local buttonPanel = vgui.Create( "DPanel", captures )
    buttonPanel:Dock( BOTTOM )
    -- buttonPanel:DockMargin( 0, 32, 0, 0 )

    local refreshButton = vgui.Create( "DButton", buttonPanel )
    refreshButton:Dock( LEFT )
    refreshButton:DockMargin( 8, 8, 8, 8 )
    refreshButton:SetText( "Refresh" )
    refreshButton:SizeToContents()

    NetMonitor.Interface.Client.Captures.Main = captures
    return captures
end
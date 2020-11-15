NetMonitor = NetMonitor or {}
NetMonitor.Interface = NetMonitor.Interface or {}

NetMonitor.Interface.Client = NetMonitor.Interface.Client or {}
NetMonitor.Interface.Client.Main = NetMonitor.Interface.Client.Main or nil

NetMonitor.Interface.Client.Captures = NetMonitor.Interface.Client.Captures or {}
NetMonitor.Interface.Client.Captures.Main = NetMonitor.Interface.Client.Captures.Main or nil
NetMonitor.Interface.Client.Captures.List = NetMonitor.Interface.Client.Captures.List or nil
NetMonitor.Interface.Client.Captures.Delete = NetMonitor.Interface.Client.Captures.Delete or nil

function NetMonitor.Interface.Client.Create(parent)
    local main = vgui.Create( "DPropertySheet", parent)
    main:Dock( FILL )
    main:AddSheet("Captures", NetMonitor.Interface.Client.CreateCapturesTab(main), "icon16/disk_multiple.png")
    main:AddSheet("Profiling", vgui.Create( "DPanel", main ), "icon16/zoom.png")
    main:AddSheet("Stats", vgui.Create( "DPanel", main ), "icon16/chart_line.png")
    main:AddSheet("Messages", vgui.Create( "DPanel", main ), "icon16/transmit.png")

    return main
end

local function RefreshCapturesList()
    NetMonitor.Interface.Client.Captures.List:Clear()

    local files, _ = file.Find( "netmon/client/*.netdat", "DATA" )
    for _, f  in ipairs(files) do
        local path = "netmon/client/" .. f
        local date = os.date( "%d/%m/%y at %H:%M:%S", file.Time( path, "DATA"))
        local size = string.NiceSize( file.Size( path, "DATA"))

        NetMonitor.Interface.Client.Captures.List:AddLine( f, date, size )
    end

    NetMonitor.Interface.Client.Captures.List:SortByColumn( 2, true )
    NetMonitor.Interface.Client.Captures.Delete:SetEnabled( false )
end

function NetMonitor.Interface.Client.CreateCapturesTab(parent)
    local captures = vgui.Create( "DPanel", parent)

    local label = vgui.Create( "DLabel", captures)
    label:Dock( TOP )
    label:DockMargin( 8, 8, 8, 0 )
    label:SetText( "Network profiling data can be found in /garrysmod/data/netmon/client/" )
    label:SetTextColor( Color(0, 0, 0) )

    local captureList = vgui.Create( "DListView", captures)
    captureList:Dock( FILL )
    captureList:DockMargin( 8, 8, 8, 0 )
    captureList:AddColumn( "Name" )
    captureList:AddColumn( "Date" )
    captureList:AddColumn( "Size" )

    function captureList:OnRowSelected(num, row)
        NetMonitor.Interface.Client.Captures.Delete:SetEnabled(true)
    end

    local buttonPanel = vgui.Create( "DPanel", captures )
    buttonPanel:Dock( BOTTOM )
    buttonPanel:SetHeight( 48 )

    local refreshButton = vgui.Create( "DButton", buttonPanel )
    refreshButton:Dock( LEFT )
    refreshButton:DockMargin( 8, 8, 8, 8 )
    refreshButton:SetText( "Refresh" )
    refreshButton:SizeToContentsX( 16 )

    refreshButton.DoClick = RefreshCapturesList

    local loadButton = vgui.Create( "DButton", buttonPanel )
    loadButton:SetEnabled( false )
    loadButton:Dock( LEFT )
    loadButton:DockMargin( 0, 8, 8, 8 )
    loadButton:SetText( "Load" )
    loadButton:SizeToContentsX( 16 )

    local unloadButton = vgui.Create( "DButton", buttonPanel )
    unloadButton:SetEnabled( false )
    unloadButton:Dock( LEFT )
    unloadButton:DockMargin( 0, 8, 8, 8 )
    unloadButton:SetText( "Unload" )
    unloadButton:SizeToContentsX( 16 )

    local deleteButton = vgui.Create( "DButton", buttonPanel )
    deleteButton:SetEnabled( false )
    deleteButton:Dock( LEFT )
    deleteButton:DockMargin( 0, 8, 8, 8 )
    deleteButton:SetText( "Delete" )
    deleteButton:SizeToContentsX( 16 )

    function deleteButton:DoClick()
        local _, selected = NetMonitor.Interface.Client.Captures.List:GetSelectedLine()
        if not selected then
            self:SetEnabled(false)
            return    
        end

        local path = "netmon/client/" .. selected:GetValue(1)
        if file.Exists(path, "DATA") then
            file.Delete(path)
        end

        RefreshCapturesList()
    end

    NetMonitor.Interface.Client.Captures.Main = captures
    NetMonitor.Interface.Client.Captures.List = captureList
    NetMonitor.Interface.Client.Captures.Delete = deleteButton

    RefreshCapturesList()
    return captures
end

function NetMonitor.Interface.Client.CreateProfilingTab(parent)
end
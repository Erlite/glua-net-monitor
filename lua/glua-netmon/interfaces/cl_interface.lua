NetMonitor = NetMonitor or {}
NetMonitor.Interface = NetMonitor.Interface or {}

-- Derma 
NetMonitor.Interface.Main = NetMonitor.Interface.Main or nil
NetMonitor.Interface.StatusBar = NetMonitor.Interface.StatusBar or nil
NetMonitor.Interface.StatusLabel = NetMonitor.Interface.StatusLabel or nil

function NetMonitor.Interface.Open()
    if not NetMonitor.Networking.Authed or NetMonitor.Interface.Main then return end

    local interface = vgui.Create("DFrame")
    interface.OnClose = function() 
        NetMonitor.Interface.Main = nil
        NetMonitor.Interface.StatusBar = nil
        NetMonitor.Interface.StatusLabel = nil

        NetMonitor.Interface.Registry.Tab = nil
        NetMonitor.Interface.Registry.SyncButton = nil
        NetMonitor.Interface.Registry.AddonsList = nil
        NetMonitor.Interface.Registry.FileList = nil
        NetMonitor.Interface.Registry.Search = nil
    end
    
    local w, h = NetMonitor.Utils.ClampToScreen(1024, 512)
    interface:SetSize( w, h )
    interface:Center()

    interface:SetMinWidth( 512 )
    interface:SetMinHeight( 256 )

    interface.btnMaxim:SetDisabled( false )
    interface.btnMaxim.DoClick = function()
        interface:SetSize( ScrW(), ScrH() )
        interface:SetPos( 0, 0 )
    end

    interface.btnMinim:SetDisabled( false )
    interface.btnMinim.DoClick = function()
        interface:SetSize( 512, 256 )
    end

    interface:SetTitle( "Net Monitor" )
    interface:SetVisible(true)
    interface:SetDraggable( true )
    interface:ShowCloseButton( true )
    interface:SetSizable( true )
    interface:SetScreenLock( true )
    interface:MakePopup()

    local tabs = vgui.Create("DPropertySheet", interface)
    tabs:AddSheet("Client", NetMonitor.Interface.Client.Create(tabs), "icon16/monitor.png")
    tabs:AddSheet("Server", vgui.Create("DPanel", tabs), "icon16/server.png")
    tabs:AddSheet("Registry", NetMonitor.Interface.Registry.Create(tabs), "icon16/table_multiple.png")
    tabs:Dock( FILL )

    local footer = vgui.Create( "DPanel", interface)
    footer.Paint = function() end
    footer:Dock( BOTTOM )
    footer:DockMargin( 0, 4, 0, 0 )

    local statusBar = vgui.Create( "DProgress", footer )
    statusBar:SetFraction( 0 )
    statusBar:SetSize( 96, 24 )
    statusBar:Dock( LEFT )

    local status = vgui.Create( "DLabel", footer)
    status:Dock( LEFT )
    status:DockMargin( 8, 0, 0, 0 )
    status:SetText("NetMonitor: Ready")
    status:SizeToContentsX()    

    local oldFunc = status.SetText
    function status:SetText(txt)
        oldFunc(self, txt)
        self:SizeToContentsX()
    end
    
    NetMonitor.Interface.Main = interface
    NetMonitor.Interface.StatusBar = statusBar
    NetMonitor.Interface.StatusLabel = status
end
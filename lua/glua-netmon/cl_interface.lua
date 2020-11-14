NetMonitor = NetMonitor or {}
NetMonitor.Interface = NetMonitor.Interface or {}

-- Derma 
NetMonitor.Interface.Main = NetMonitor.Interface.Main or nil
NetMonitor.Interface.RegistryTab = NetMonitor.Interface.RegistryTab or nil
NetMonitor.Interface.RegistrySyncButton = NetMonitor.Interface.RegistrySyncButton or nil
NetMonitor.Interface.RegistrySearch = NetMonitor.Interface.RegistrySearch or nil
NetMonitor.Interface.RegistryAddonsList = NetMonitor.Interface.RegistryAddonsList or nil
NetMonitor.Interface.RegistryFileList = NetMonitor.Interface.RegistryFileList or nil
NetMonitor.Interface.StatusBar = NetMonitor.Interface.StatusBar or nil
NetMonitor.Interface.StatusLabel = NetMonitor.Interface.StatusLabel or nil

function NetMonitor.Interface.Open()
    if not NetMonitor.Networking.Authed or NetMonitor.Interface.Main then return end

    local interface = vgui.Create("DFrame")
    interface.OnClose = function() 
        NetMonitor.Interface.Main = nil
        NetMonitor.Interface.Main = nil
        NetMonitor.Interface.RegistryTab = nil
        NetMonitor.Interface.RegistrySyncButton = nil
        NetMonitor.Interface.RegistryAddonsList = nil
        NetMonitor.Interface.RegistryFileList = nil
        NetMonitor.Interface.RegistrySearch = nil
        NetMonitor.Interface.StatusBar = nil
        NetMonitor.Interface.StatusLabel = nil
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
    tabs:AddSheet("Stats", vgui.Create("DPanel", tabs), "icon16/transmit.png")
    tabs:AddSheet("Registry", NetMonitor.Interface.CreateRegistryInterface(tabs), "icon16/table_multiple.png")
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

local function SearchMatchesPath(searchTerm, path)
    if NetMonitor.Interface.RegistrySearch.ignore then return true end
    if #searchTerm == 0 then return true end
    
    local goodPattern, pos = pcall(string.find, path, searchTerm)
    if not goodPattern then
        local pos, _, _ = string.find(path, searchTerm, 1, true)
        return pos != nil
    end

    return pos != nil
end

local function UpdateRegistryDisplay(refreshAddons, refreshFiles)
    if not NetMonitor.Interface.RegistryAddonsList or not NetMonitor.Interface.RegistryFileList then return end

    refreshFiles = refreshAddons or refreshFiles 

    if refreshAddons then NetMonitor.Interface.RegistryAddonsList:Clear() end
    if refreshFiles then NetMonitor.Interface.RegistryFileList:Clear() end

    local isFirst = true
    local addedLines = {}

    local _, selected = NetMonitor.Interface.RegistryAddonsList:GetSelectedLine()
    local selectedName = selected and selected:GetValue( 1 ) or nil
    local searchTerm = NetMonitor.Interface.RegistrySearch:GetValue()

    searchTerm = string.TrimLeft(searchTerm)
    searchTerm = string.TrimRight(searchTerm)

    -- Limited to 512 elements. 
    local amount = 0
    if selectedName == "*" or selectedName == nil then
        local isFirst = true
        for addon, files in pairs(NetMonitor.Registry.AddonFiles) do
            if refreshAddons then
                if isFirst then 
                    NetMonitor.Interface.RegistryAddonsList:AddLine("*")
                    NetMonitor.Interface.RegistryAddonsList:SelectFirstItem()
                    local _, all = NetMonitor.Interface.RegistryAddonsList:GetSelectedLine()
                    all:SetToolTip("Displays all registered lua files, limited to 512 files.")

                    isFirst = false
                end

                NetMonitor.Interface.RegistryAddonsList:AddLine(addon)
            end

            if refreshFiles then
                for _, path in ipairs(files) do
                    if SearchMatchesPath(searchTerm:lower(), path) then
                        if amount < 512 then
                            NetMonitor.Interface.RegistryFileList:AddLine(path)
                            amount = amount + 1
                        end
                    end
                end
            end
        end
        return
    end

    for addon, files in pairs(NetMonitor.Registry.AddonFiles) do
        if not addedLines[addon] and refreshAddons then    
            NetMonitor.Interface.RegistryAddonsList:AddLine(addon)
            addedLines[addon] = true
        end

        if refreshAddons and isFirst then
            NetMonitor.Interface.RegistryAddonsList:SelectFirstItem()
            isFirst = false

            for _, path in ipairs(files) do
                if SearchMatchesPath(searchTerm:lower(), path) then
                    NetMonitor.Interface.RegistryFileList:AddLine(path)
                end
            end
        elseif refreshFiles and addon == selectedName then
            for _, path in ipairs(files) do
                if SearchMatchesPath(searchTerm:lower(), path) then
                    NetMonitor.Interface.RegistryFileList:AddLine(path)
                end
            end
        end
    end 

end

hook.Add("OnNetRegistryUpdated", "NetmonInterfaceUpdateReg", function() UpdateRegistryDisplay(true, true) end)

function NetMonitor.Interface.CreateRegistryInterface(parent)
    local registry = vgui.Create( "DPanel", parent, "Registry" )
    local leftPanel = vgui.Create( "DPanel", registry)

    -- Left side of the registry will be a list of addons
    local syncButton = vgui.Create( "DButton", leftPanel )
    syncButton:SetText( "Synchronize Registry" )
    syncButton:Dock( TOP )
    syncButton:DockMargin( 8, 8, 8, 8 )

    function syncButton:DoClick()
        NetMonitor.Networking.RequestRegistry()
        self:SetEnabled(false)
        NetMonitor.Interface.StatusLabel:SetText("NetMonitor: Requesting registry from the server...")
        NetMonitor.Interface.StatusBar:SetFraction( 0.3 )
    end

    local addonList = vgui.Create( "DListView", leftPanel )
    addonList:Dock( FILL )
    addonList:DockMargin( 8, 0, 8, 8 )
    addonList:AddColumn( "Sources" )

    local onClickLine = addonList.OnClickLine

    function addonList:OnClickLine(line, isSelected)
        onClickLine(self, line, isSelected)
        UpdateRegistryDisplay(false, true)
    end
    
    -- Disable synchronizing the registry if you're the server host.
    if game.SinglePlayer() or NetMonitor.Networking.IsHost then
        syncButton:SetEnabled( false )
        syncButton:SetTooltip( "Cannot synchronize registry when you're the host: you already have everything." )
    else
        syncButton:SetTooltip( "Request the server's registry, you only need to do this once." )
    end

    local rightPanel = vgui.Create( "DPanel", registry )

    local searchBar = vgui.Create( "DTextEntry", rightPanel )
    searchBar:SetText(" Search...")
    searchBar:Dock( TOP )
    searchBar:DockMargin( 8, 8, 8, 8 )
    searchBar.ignore = true

    function searchBar:OnGetFocus()
        self:SetValue("")
    end

    function searchBar:OnLoseFocus()
        local str = self:GetValue()
        str = string.Replace(str, " ",  "")

        if #str == 0 then 
            self:SetText(" Search...") 
            self.ignore = true    
        end
    end

    function searchBar:OnChange()
        local value = self:GetValue()
        value = string.TrimLeft(value)
        value = string.TrimRight(value)

        searchBar.ignore = #value == 0
        UpdateRegistryDisplay(false, true)
    end

    local pathList = vgui.Create( "DListView", rightPanel)
    pathList:Dock( FILL )
    pathList:DockMargin( 8, 2, 8, 8 )
    pathList:AddColumn( "File Path" )
    pathList:SetMultiSelect( false )

    local divider = vgui.Create( "DHorizontalDivider", registry )
    divider:Dock( FILL )
    divider:SetLeft( leftPanel )
    divider:SetRight( rightPanel )
    divider:SetDividerWidth( 8 )  
    divider:SetLeftMin( 196 )  

    pathList.OnSizeChanged = function(newW, newH)
        local x, y = divider:GetSize()
        divider:SetRightMin(x - 256)
    end

    NetMonitor.Interface.Registry = registry
    NetMonitor.Interface.RegistryAddonsList = addonList
    NetMonitor.Interface.RegistryFileList = pathList
    NetMonitor.Interface.RegistrySyncButton = syncButton
    NetMonitor.Interface.RegistrySearch = searchBar

    -- Populate the registry list
    UpdateRegistryDisplay(true, true)

    return registry
end
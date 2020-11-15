NetMonitor = NetMonitor or {}
NetMonitor.Interface = NetMonitor.Interface or {}
NetMonitor.Interface.Registry = NetMonitor.Interface.Registry or {}

NetMonitor.Interface.Registry.Tab = NetMonitor.Interface.Registry.Tab or nil
NetMonitor.Interface.Registry.SyncButton = NetMonitor.Interface.Registry.SyncButton or nil
NetMonitor.Interface.Registry.Search = NetMonitor.Interface.Registry.Search or nil
NetMonitor.Interface.Registry.AddonsList = NetMonitor.Interface.Registry.AddonsList or nil
NetMonitor.Interface.Registry.FileList = NetMonitor.Interface.Registry.FileList or nil

local function UpdateRegistryDisplay(refreshAddons, refreshFiles)
    if not NetMonitor.Interface.Registry.AddonsList or not NetMonitor.Interface.Registry.FileList then return end

    refreshFiles = refreshAddons or refreshFiles 

    if refreshAddons then NetMonitor.Interface.Registry.AddonsList:Clear() end
    if refreshFiles then NetMonitor.Interface.Registry.FileList:Clear() end

    local isFirst = true
    local addedLines = {}

    local _, selected = NetMonitor.Interface.Registry.AddonsList:GetSelectedLine()
    local selectedName = selected and selected:GetValue( 1 ) or nil
    local searchTerm = NetMonitor.Interface.Registry.Search:GetValue()

    searchTerm = string.TrimLeft(searchTerm)
    searchTerm = string.TrimRight(searchTerm)

    -- Limited to 512 elements. 
    local amount = 0
    if selectedName == "*" or selectedName == nil then
        local isFirst = true
        for addon, files in pairs(NetMonitor.Registry.AddonFiles) do
            if refreshAddons then
                if isFirst then 
                    NetMonitor.Interface.Registry.AddonsList:AddLine("*")
                    NetMonitor.Interface.Registry.AddonsList:SelectFirstItem()
                    local _, all = NetMonitor.Interface.Registry.AddonsList:GetSelectedLine()
                    all:SetToolTip("Displays all registered lua files, limited to 512 files.")

                    isFirst = false
                end

                NetMonitor.Interface.Registry.AddonsList:AddLine(addon)
            end

            if refreshFiles then
                for _, path in ipairs(files) do
                    if NetMonitor.Interface.Registry.Search.ignore or NetMonitor.Utils.StringMatchesSearch(searchTerm:lower(), path) then
                        if amount < 512 then
                            NetMonitor.Interface.Registry.FileList:AddLine(path)
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
            NetMonitor.Interface.Registry.AddonsList:AddLine(addon)
            addedLines[addon] = true
        end

        if refreshAddons and isFirst then
            NetMonitor.Interface.Registry.AddonsList:SelectFirstItem()
            isFirst = false

            for _, path in ipairs(files) do
                if NetMonitor.Interface.Registry.Search.ignore or NetMonitor.Utils.StringMatchesSearch(searchTerm:lower(), path) then
                    NetMonitor.Interface.Registry.FileList:AddLine(path)
                end
            end
        elseif refreshFiles and addon == selectedName then
            for _, path in ipairs(files) do
                if NetMonitor.Interface.Registry.Search.ignore or NetMonitor.Utils.StringMatchesSearch(searchTerm:lower(), path) then
                    NetMonitor.Interface.Registry.FileList:AddLine(path)
                end
            end
        end
    end 

end

hook.Add("OnNetRegistryUpdated", "NetmonInterfaceUpdateReg", function() UpdateRegistryDisplay(true, true) end)

function NetMonitor.Interface.Registry.Create(parent)
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
    searchBar:SetTooltip( "Search the file paths for the specified string, supports patterns.")
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

    NetMonitor.Interface.Registry.Tab = registry
    NetMonitor.Interface.Registry.AddonsList = addonList
    NetMonitor.Interface.Registry.FileList = pathList
    NetMonitor.Interface.Registry.SyncButton = syncButton
    NetMonitor.Interface.Registry.Search = searchBar

    -- Populate the registry list
    UpdateRegistryDisplay(true, true)

    return registry
end
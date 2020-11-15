print("======================================")
print("= Net Message Monitor by Erlite v1.0 =")
print("======================================")

print()
print("Overriding net and umsg library functions to capture messages.")
print("Do note that any addon who does so as well without calling base functions will probably not work with this one.")
print()

local function ClientInclude(path)
    if SERVER then 
        AddCSLuaFile(path)
    else 
        include(path) 
    end
end

if SERVER then include("glua-netmon/sv_config.lua") end

ClientInclude("glua-netmon/cl_config.lua")

include("glua-netmon/utils.lua")
include("glua-netmon/binarychunk.lua")
include("glua-netmon/capturedmessage.lua")
include("glua-netmon/registry.lua")
include("glua-netmon/profiler.lua")
include("glua-netmon/netmon.lua")
include("glua-netmon/hooks.lua")

if SERVER then 
    include("glua-netmon/sv_net.lua")
    AddCSLuaFile("glua-netmon/cl_net.lua")
else
    include("glua-netmon/cl_net.lua")
end

-- Net monitor UI files
ClientInclude("glua-netmon/interfaces/cl_clienttab.lua")
ClientInclude("glua-netmon/interfaces/cl_registrytab.lua")
ClientInclude("glua-netmon/interfaces/cl_interface.lua")


-- Create capture folders if they don't exist.
if NetMonitor.Utils.VerifyDataFolders() then
    print("Created capture data folders.")
end

print()
print("Done!")
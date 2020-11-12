print("======================================")
print("= Net Message Monitor by Erlite v1.0 =")
print("======================================")

print()
print("Overriding net library functions to capture messages.")
print("Do note that any addon who does so as well without calling base functions will probably not work with this one.")
print()

include("glua-netmon/sv_config.lua")

AddCSLuaFile("glua-netmon/cl_config.lua")
if CLIENT then include("glua-netmon/cl_config.lua") end

include("glua-netmon/utils.lua")
include("glua-netmon/capturedmessage.lua")
include("glua-netmon/registry.lua")
include("glua-netmon/netmon.lua")
include("glua-netmon/stats.lua")
include("glua-netmon/hooks.lua")

print()
print("Done!")
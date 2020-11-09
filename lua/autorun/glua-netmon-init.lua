print("======================================")
print("= Net Message Monitor by Erlite v1.0 =")
print("======================================")

print()
print("Overriding net library functions to capture messages.")
print("Do note that any addon who does so as well without calling base functions will probably not work with this one.")

include("glua-netmon/capturedmessage.lua")
include("glua-netmon/net_monitor.lua")
include("glua-netmon/hooks.lua")

print()
print("Done!")
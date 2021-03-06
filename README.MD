
# gLua Net Monitor
A simple utility that captures outgoing and incoming net messages to help you debug and optimize bandwidth.
Supports both the net library and the deprecated umsg library (please update your addons if you still use it).

![Net Monitor Example](https://i.imgur.com/nGGLrVG.png)

## Installation

Simply drop the `gLua-net-monitor` folder in your `garrysmod/addons` folder, it'll work by itself.

## Compatibility
Addons that override any net/umsg/bf_read function overrides must call the base implementation for this to work.
Overriding `net.Incoming` might stop this utility from capturing incoming messages since it requires the message header to work.

## Hooks
By default, the `hooks.lua` file contains some basic implementations for debugging. Feel free to get rid of them.

### OnNetMessageStarted
```lua
-- Called when a net message is started.
-- @param msgName: name of the message that was started.
-- @param funcInfo: info about the function that started the message.
hook.Add("OnNetMessageStarted", "NetStarted", function(msgName, funcInfo) end)
```

### OnNetMessageCaptured

```lua
-- Called when a net message is captured, for both outgoing and incoming messages.
-- Keep your code fast in here! This is called for every net/umsg message.
-- @param msg: The captured message, see NetMonitor.CapturedMessage
-- @param funcInfo: For outgoing messages, the function who started the message.
hook.Add("OnNetMessageCaptured", "NetCaptured", function(msg, funcInfo) end)
```

### OnNetMessageIgnored
```lua
-- Called when a net message is received but no receiving function is hooked.
-- This is likely an oversight of a developer, albeit a wasteful one.
-- @param msg: The captured message, see NetMonitor.CapturedMessage
hook.Add("OnNetMessageIgnored", "NetIgnored", function(msg) end)
```

### OnNetMessageDumpedData
```lua
-- Called when a received net message does not read all the received data.
-- Not called for the usermessage lib messages.
-- Called after OnNetMessageCaptured & OnNetMessageIgnored
-- This means you or an addon on your server is wasting bandwidth!
-- @param msg: The captured message, see NetMonitor.CapturedMessage
-- @note: The captured message data will contain a binary string dump of the remaining data.
hook.Add("OnNetMessageDumpedData", "NetDumped", function(msg) end)
```

### OnNetMessageDiscarded
```lua
-- Called when a net message is discarded due to starting another without finishing the current one.
-- @param msg: The captured message which got discarded, likely missing some information.
-- @param funcInfo: The info about the function which called the dicarded message's net.Start() 
hook.Add("OnNetMessageDiscarded", "NetDiscarded", function(msg, funcInfo) end)
```

### OnNetRegistryUpdated
```lua
-- Called clientside when the server's registry is received.
hook.Add("OnNetRegistryUpdated", "NetRegistryUpdate", function() end)
```
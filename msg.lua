-- msg.lua
--
-- Queues things to happen a few frames later, for everyone.
-- (The server needs to remember everything that's happened and call
--  that a save file.)

--local class = require("middleclass")

package.cpath = package.cpath .. ";?.dylib"
local enet = require("enet")

local msg = {
    hooks = {}, -- list of actions we accept calls for

    q = {}, -- actions queued to be sent this tick

    recv = {}, -- frames we have information for from server
    sent = {}, -- for debugging

    tickTime = 100, -- ms
    tickDelay = 3,

    currentTick = 1,
    tickAccum = 0,

    qAccum = 0
}

function msg.connect(address) -- e.g. "localhost:6789"
    local host = enet.host_create()
    local server = host:connect(address, 2)
    msg.host = host
    msg.server = server
    -- Why not set directly? -> What if host:connect() fails?
    
    -- send test message!
    host:service(0)

end

function msg.disconnect()
    msg.server:disconnect()
    msg.host:flush()
    msg.server = nil
    msg.host = nil
end

function msg.broadcast(action, args)
    if not msg.server then
        print("[warn] msg.broadcast before connected")
    end

    msg.q[#msg.q + 1] = {action = action, args = args}
end

function msg.update(dt)

    if not msg.server then
        print("[warn] msg.update when not connected. ignoring")
        return
    end

    local ev = true
    while ev do
        ev = msg.host:service(0) -- non-blocking, i hope!
        if ev then
            if ev.type == "connect" then
                print("[warn] msg.update() found connect ev. shouldn't happen on client-side?")
                ev.peer:send("1 test_hook test_data", 1)
            elseif ev.type == "disconnect" then
                print("[warn] msg.update() saw disconnect")
                -- TODO: throw?
            elseif ev.type == "receive" then
                print(ev.data)
                
            end
            -- deal with incoming ev
            -- ev.type == "connect" then // ev.peer:send
            -- ev.type == "disconnect" then  (set .server, .host to nil? signal failure?)
            -- ev.type == "receive" then // ... ev.data, ev.peer. ev.data is Lua string
        end
    end

    msg.tickAccum = msg.tickAccum + dt
    msg.qAccum = msg.qAccum + dt

    local broken = false

    -- check for control messages

    while msg.tickAccum > msg.tickTime do
        if msg.recv[msg.currentTick] then
            -- exec
            print("msg: exec tick " .. msg.currentTick)
        else
            print("msg: network tick " .. msg.currentTick .. " is late")
            broken = true
            break
        end
        
        msg.tickAccum = msg.tickAccum - msg.tickTime
        msg.currentTick = msg.currentTick + 1
    end

    -- TODO: something better than not sending for the case where net recv is late
    if not broken and msg.qAccum > msg.tickTime then
        msg.qAccum = msg.qAccum % msg.tickTime

        local t = msg.currentTick + msg.tickDelay

        -- package up & send msg.q, for frame (msg.currentTick + msg.tickDelay)
        -- get .peer from connect ev, call :send() with string containing serialized q

        msg.sent[t] = msg.q
        msg.q = {}
    end

end

return msg

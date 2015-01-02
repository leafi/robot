-- server_only.lua
-- 
-- The server that all the clients connect to.
--
-- Waits for everyone to send data for a particular tick, then tells everyone
-- about the results once that has come to pass.

package.cpath = package.cpath .. ";../?.dylib" -- need to change for non-mac
local enet = require("enet")

local host = enet.host_create("0.0.0.0:32501", 64, 2)

local qs = {} -- queue of packets for each tick
local allpeers = {}

local tick = 1

-- TODO: use unreliable broadcast for game messages, collate messages & spam
-- (so we're never waiting for tick 1 when messages for tick 2 & 3 got through)

while true do
    local ev = host:service(50)
    local peer_idx = ev and ev.peer:index()

    if ev and ev.type == "connect" then
        print(peer_idx .. " connected")

        allpeers[peer_idx] = ev.peer
        if not qs[peer_idx] then
            qs[peer_idx] = {}
        end

        -- Note that the client is responsible for sending null ticks to let the
        -- game proceed, while it syncs.
        -- (The game effectively pauses instantly once the player has connected,
        --  as we're missing the new player's data for the next frame.)

        host:broadcast("HI " .. peer_idx .. " tick " .. tick, 0)

        -- TODO: send previous game state to new peer!
    elseif ev and ev.type == "disconnect" then
        print(peer_idx .. " disconnected")
        table.remove(allpeers, peer_idx)
        host:broadcast("XX " .. peer_idx, 0)

        -- TODO: look for future ticks containing stuff this peer has already sent,
        -- and delete it. (e.g. what if id is re-used?)

        -- TODO: also, store disconnect event for later-joining peers.
        -- (connection/new player events happen in game messages, but disconnects
        --  happen out-of-band.)
    elseif ev and ev.type == "receive" then
        print(peer_idx .. " ch" .. ev.channel .. " recv (" .. ev.data .. ")")

        -- TODO: ensure msg is in format "$tick $hook $data"
        -- ..and that the appropriate fields are ints!
        -- ..and validate message length!

        -- debug
        --[[for k, v in pairs(ev) do
            local sv = ""
            if pcall(function() sv = sv .. v end) then
                print(k .. ": " .. sv)
            else
                print(k .. ": [userdata]")
            end
        end]]--

        -- out-of-band or in-game?
        if ev.channel == 0 then
            -- CERR?
            if ev.data:sub(1, 4) == "CERR" then
                host:broadcast("CERR " .. peer_idx .. " " .. ev.data:sub(6), 0)
                print("CERR " .. peer_idx .. " " .. ev.data:sub(6))
            else
                host:broadcast("SERR " .. peer_idx .. " malformed_control_msg", 0)
                print("SERR " .. peer_idx .. " malformed_control_msg")
            end
        elseif ev.channel == 1 then
            -- in-game, then!
            local msg_tick = ev.data:sub(1, ev.data:find(" ") - 1)
            local msg = ev.data:sub(ev.data:find(" ") + 1)

            -- player can only send info for tick once
            if qs[peer_idx][msg_tick] then
                print("SERR " .. peer_idx .. " already_sent " .. msg_tick)
                host:broadcast("SERR " .. peer_idx .. " already_sent " .. msg_tick, 0)
            else

                -- TODO: player probably shouldn't be sending messages TOO far ahead

                -- TODO: id players slowing down game

                -- Note that an empty message field is acceptable, and simply
                -- means the user did nothing of note.

                qs[peer_idx][tonumber(msg_tick)] = msg
                print("stored " .. msg .. " for " .. peer_idx .. " in tick " .. msg_tick)
            end
        end

    end

    -- ready to send?
    while #allpeers > 0 do
        ok = true
        for k, v in ipairs(qs) do
            ok = v[tick] and ok
        end

        if not ok then
            break
        end

        -- still here? we're ready!
        local peers = {}
        local lengths = {}
        local messages = {}
        for k, v in ipairs(qs) do
            peers[#peers + 1] = k
            lengths[#lengths + 1] = v[tick]:len()
            messages[#messages + 1] = v[tick]
        end

        -- broadcast a huge message of everything on channel 1
        print("BROADCAST:")
        local m = tick .. " " .. #peers .. " " .. table.concat(peers, " ") .. " "
            .. table.concat(lengths, " ") .. " " .. table.concat(messages)
        print(m)
        host:broadcast(m, 1)

        tick = tick + 1

    end
end




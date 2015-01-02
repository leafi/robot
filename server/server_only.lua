-- server_only.lua
-- 
-- The server that all the clients connect to.
--
-- Waits for everyone to send data for a particular frame, then tells everyone
-- about the results once that has come to pass.

package.cpath = package.cpath .. ";../?.dylib" -- need to change for non-mac
local enet = require("enet")

local host = enet.host_create("0.0.0.0:32501", 64, 2)

local qs = {} -- queue of packets for each frame
local allpeers = {}

local frame = 1

-- TODO: use unreliable broadcast for game messages, collate messages & spam
-- (so we're never waiting for frame 1 when messages for frame 2 & 3 got through)

while true do
    local ev = host:service(50)
    local peer_idx = ev and ev.peer:index()

    if ev and ev.type == "connect" then
        print(peer_idx .. " connected")
        allpeers[peer_idx] = false -- client is responsible for sending null frames
                                   -- to let the game proceed while it syncs
                                   -- ^^^ INACCURATE; allpeers means something else!
        if not qs[peer_idx] then
            qs[peer_idx] = {}
        end

        host:broadcast("HI " .. peer_idx .. " frame " .. frame, 0)

        -- TODO: send previous game state to new peer!
    elseif ev and ev.type == "disconnect" then
        print(peer_idx .. " disconnected")
        table.remove(allpeers, peer_idx)
        host:broadcast("XX " .. peer_idx, 0)

        -- TODO: look for future frames containing stuff this peer has already sent,
        -- and delete it. (e.g. what if id is re-used?)

        -- TODO: also, store disconnect event for later-joining peers.
        -- (connection/new player events happen in game messages, but disconnects
        --  happen out-of-band.)
    elseif ev and ev.type == "receive" then
        print(peer_idx .. " ch" .. ev.channel .. " recv (" .. ev.data .. ")")
        -- TODO: ensure msg is in format "$frame $hook $data"
        --host:broadcast(peer_idx .. " " .. event.data)

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
            local msg_frame = ev.data:sub(1, ev.data:find(" ") - 1)
            local msg = ev.data:sub(ev.data:find(" ") + 1)

            -- player can only send info for frame once
            if qs[peer_idx][msg_frame] then
                print("SERR " .. peer_idx .. " already_sent " .. msg_frame)
                host:broadcast("SERR " .. peer_idx .. " already_sent " .. msg_frame, 0)
            else

                -- TODO: player probably shouldn't be sending messages TOO far ahead

                -- TODO: id players slowing down game

                qs[peer_idx][tonumber(msg_frame)] = msg
                print("stored " .. msg .. " for " .. peer_idx .. " in frame " .. msg_frame)
                shok = true
                
            end
        end

    end

    -- ready to send?
    while #allpeers > 0 do
        ok = true
        for k, v in ipairs(qs) do
            ok = v[frame] and ok
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
            lengths[#lengths + 1] = v[frame]:len()
            messages[#messages + 1] = v[frame]
        end

        -- broadcast a huge message of everything on channel 1
        print("BROADCAST:")
        local m = frame .. " " .. #peers .. " " .. table.concat(peers, " ") .. " "
            .. table.concat(lengths, " ") .. " " .. table.concat(messages)
        print(m)
        host:broadcast(m, 1)

        frame = frame + 1

    end
end




-- =========================================================================
-- 465 AC v4.2.0 - İSTEMCİ THREAD FREEZE & HANDSHAKE BEKÇİSİ
-- =========================================================================

local playerJoinTimes = {}

AddEventHandler("playerJoining", function()
    local src = source
    playerJoinTimes[src] = os.time()
end)

AddEventHandler("playerDropped", function()
    local src = source
    playerJoinTimes[src] = nil
end)

CreateThread(function()
    while true do
        Wait(10000)
        if ONLY_AC_Shared.IsModuleEnabled("AntiThreadFreeze") then
            local currentTime = os.time()
            local handshakeTimeout = Config.HandshakeTimeoutSeconds or 40
            local heartbeatTimeout = Config.HeartbeatTimeoutSeconds or 30

            for _, playerId in ipairs(GetPlayers()) do
                local src = tonumber(playerId)
                if src and src > 0 and not ONLY_AC.IsBypass(src) then
                    local lastBeat = ONLY_AC.GetLastHeartbeat(src)
                    local joinTime = playerJoinTimes[src] or currentTime

                    if not lastBeat then
                        if (currentTime - joinTime) > handshakeTimeout then
                            ONLY_AC.Detect(src, "İstemci Başlatılamadı / Handshake Eksik", ("Girişten itibaren %s sn geçti"):format(currentTime - joinTime), "kick", "AntiThreadFreeze")
                        end
                    else
                        local diff = currentTime - lastBeat
                        if diff > heartbeatTimeout then
                            ONLY_AC.Detect(src, "İstemci Koruma Döngüsü Donduruldu (Thread Freeze)", ("Son sinyal: %s sn önce"):format(diff), "kick", "AntiThreadFreeze")
                        end
                    end
                end
            end
        end
    end
end)

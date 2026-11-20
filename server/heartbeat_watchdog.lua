-- =========================================================================
-- ONLY AC v3.0.0 (ULTIMATE EDITION) - ISTEMCI THREAD VE DONDURMA BEKÇİSİ
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

if Config.Protections.AntiThreadFreeze then
    CreateThread(function()
        while true do
            Wait(10000)
            local currentTime = os.time()
            local players = GetPlayers()

            for _, playerId in ipairs(players) do
                local src = tonumber(playerId)
                if src and src > 0 and not ONLY_AC.IsBypass(src) then
                    local lastBeat = ONLY_AC.GetLastHeartbeat(src)
                    local joinTime = playerJoinTimes[src] or currentTime

                    -- 1. Handshake Zaman Aşımı Kontrolü (Client script yüklenmedi veya engellendi)
                    if not lastBeat then
                        if (currentTime - joinTime) > (Config.HandshakeTimeoutSeconds or 35) then
                            ONLY_AC.Detect(src, "İstemci Başlatılamadı / Handshake Eksik (AC Bypass Girişimi)", ("Girişten itibaren %s sn geçti"):format(currentTime - joinTime), "kick")
                        end
                    else
                        -- 2. Heartbeat Sinyal Kesintisi Kontrolü (Thread donduruldu / loop durduruldu)
                        local diff = currentTime - lastBeat
                        local maxTimeout = Config.HeartbeatTimeoutSeconds or 30
                        if diff > maxTimeout then
                            ONLY_AC.Detect(src, "Anti-Cheat Döngüsü Donduruldu / Durduruldu (Thread Freeze)", ("Son sinyal: %s sn önce"):format(diff), "kick")
                        end
                    end
                end
            end
        end
    end)
end

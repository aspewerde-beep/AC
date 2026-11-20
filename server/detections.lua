-- =========================================================================
-- ONLY AC v4.1.0 (ENTERPRISE EDITION) - SUNUCU TARAFLI DOĞRUDAN TESPİTLER
-- (ENTITY, EXPLOSION, PARTICLE, CRASHER, PED SPAM, MASS DAMAGE & EVENT GUARDS)
-- Standartlar: FeloxAC v4.1 (Vanity, South, Sound Crashers & Object Whitelist)
-- =========================================================================

local playerExplosions = {}
local playerEntitySpawns = {}
local playerParticles = {}
local playerPedSpawns = {}
local playerDamageTargets = {}
local playerWeaponPickups = {}
local playerSpeechSpam = {}

-- 1. ENTITY SPAWN KORUMASI (Yasaklı Obje / Araç / NPC & Spam Tespiti & Obje Whitelist)
if Config.Protections.AntiEntitySpam then
    AddEventHandler("entityCreating", function(entity)
        if not DoesEntityExist(entity) then return end

        local owner = NetworkGetEntityOwner(entity)
        if not owner or owner <= 0 then return end

        -- Bypass yetkisi kontrolü
        if ONLY_AC.IsBypass(owner) then return end

        local model = GetEntityModel(entity)

        -- 🛡️ GÜVENLİ OBJE KONTROLÜ (Object Whitelist - FeloxAC v2.0 Standardı)
        -- Telefon, defter, şemsiye, yiyecek gibi masum RP objeleri kontrolü atlar
        if Config.ObjectWhitelist and Config.ObjectWhitelist[model] then
            return
        end

        -- Yasaklı Model Kontrolü
        if Config.BlacklistedModels and Config.BlacklistedModels[model] then
            CancelEvent()
            ONLY_AC.Detect(owner, "Yasaklı Model Spawn Etme Girişimi", ("Model Hash: %s"):format(model), "ban")
            return
        end

        -- Entity Spam Kontrolü (Crasher Koruması)
        local currentTime = os.time()
        if not playerEntitySpawns[owner] then
            playerEntitySpawns[owner] = { count = 1, timestamp = currentTime }
        else
            local record = playerEntitySpawns[owner]
            if (currentTime - record.timestamp) <= (Config.EntityWindowSeconds or 5) then
                record.count = record.count + 1
                if record.count > (Config.MaxEntitySpawnsPerWindow or 6) then
                    CancelEvent()
                    ONLY_AC.Detect(owner, "Toplu Obje / Araç Basma (Entity Spam / Crasher)", ("%s saniyede %s entity"):format(Config.EntityWindowSeconds, record.count), "ban")
                    return
                end
            else
                record.count = 1
                record.timestamp = currentTime
            end
        end
    end)
end

-- 2. PATLAMA KORUMASI (Blacklisted Explosions & Explosion Spam)
if Config.Protections.AntiExplosionSpam then
    AddEventHandler("explosionEvent", function(sender, ev)
        local src = sender
        if not src or src <= 0 then return end

        -- Bypass kontrolü
        if ONLY_AC.IsBypass(src) then return end

        local expType = ev.explosionType

        -- Yasaklı Patlama Türü Kontrolü
        if Config.BlacklistedExplosions and Config.BlacklistedExplosions[expType] then
            CancelEvent()
            ONLY_AC.Detect(src, "Yasaklı Patlama Türü Oluşturuldu", ("Patlama Tipi: %s"):format(expType), "ban")
            return
        end

        -- Patlama Spam Kontrolü
        local currentTime = os.time()
        if not playerExplosions[src] then
            playerExplosions[src] = { count = 1, timestamp = currentTime }
        else
            local record = playerExplosions[src]
            if (currentTime - record.timestamp) <= (Config.ExplosionWindowSeconds or 5) then
                record.count = record.count + 1
                if record.count > (Config.MaxExplosionsPerWindow or 3) then
                    CancelEvent()
                    ONLY_AC.Detect(src, "Toplu Patlama Oluşturma (Explosion Spam)", ("%s saniyede %s patlama"):format(Config.ExplosionWindowSeconds, record.count), "ban")
                    return
                end
            else
                record.count = 1
                record.timestamp = currentTime
            end
        end
    end)
end

-- 3. PARTİKÜL / EFEKT SPAM KORUMASI (ptFxEvent Crasher Koruması)
if Config.Protections.AntiParticleSpam then
    AddEventHandler("ptFxEvent", function(sender, data)
        local src = sender
        if not src or src <= 0 then return end
        if ONLY_AC.IsBypass(src) then return end

        local currentTime = os.time()
        if not playerParticles[src] then
            playerParticles[src] = { count = 1, timestamp = currentTime }
        else
            local record = playerParticles[src]
            if (currentTime - record.timestamp) <= (Config.ParticleWindowSeconds or 3) then
                record.count = record.count + 1
                if record.count > (Config.MaxParticlePerWindow or 4) then
                    CancelEvent()
                    ONLY_AC.Detect(src, "Partikül / Efekt Spamı (FPS Düşürme / Crasher)", ("%s saniyede %s efekt"):format(Config.ParticleWindowSeconds, record.count), "kick")
                    return
                end
            else
                record.count = 1
                record.timestamp = currentTime
            end
        end
    end)
end

-- 4. UZAKTAN ANİMASYON DONDURMA KORUMASI (Anti Clear Tasks)
if Config.Protections.AntiClearTasks then
    AddEventHandler("clearPedTasksEvent", function(sender, data)
        local src = sender
        if not src or src <= 0 then return end
        if ONLY_AC.IsBypass(src) then return end

        if data and data.pedId and data.pedId ~= GetPlayerPed(src) then
            CancelEvent()
            ONLY_AC.Detect(src, "Uzaktan Oyuncu Dondurma (ClearPedTasks Abuse)", "Hedef ped üzerinde yetkisiz işlem", "ban")
        end
    end)
end

-- 5. TOPLU NPC BASMA KORUMASI (Anti Ped Spam)
if Config.Protections.AntiPedSpam then
    AddEventHandler("entityCreating", function(entity)
        if not DoesEntityExist(entity) then return end
        local entityType = GetEntityType(entity)
        if entityType ~= 1 then return end -- 1 = Ped

        local owner = NetworkGetEntityOwner(entity)
        if not owner or owner <= 0 then return end
        if ONLY_AC.IsBypass(owner) then return end

        local currentTime = os.time()
        if not playerPedSpawns[owner] then
            playerPedSpawns[owner] = { count = 1, timestamp = currentTime }
        else
            local record = playerPedSpawns[owner]
            if (currentTime - record.timestamp) <= (Config.PedWindowSeconds or 5) then
                record.count = record.count + 1
                if record.count > (Config.MaxPedSpawnsPerWindow or 4) then
                    CancelEvent()
                    ONLY_AC.Detect(owner, "Toplu NPC Basma (Ped Spam)", ("%s saniyede %s ped"):format(Config.PedWindowSeconds or 5, record.count), "ban")
                    return
                end
            else
                record.count = 1
                record.timestamp = currentTime
            end
        end
    end)
end

-- 6. TOPLU HASAR / KILL-ALL KORUMASI (Mass Damage / Rapid Multi-Target Hit)
AddEventHandler("weaponDamageEvent", function(sender, data)
    local attacker = sender
    if not attacker or attacker <= 0 then return end
    if ONLY_AC.IsBypass(attacker) then return end

    local targetEntity = NetworkGetEntityFromNetworkId(data.hitGlobalId)
    if not DoesEntityExist(targetEntity) or not IsPedAPlayer(targetEntity) then return end

    local targetPlayer = NetworkGetEntityOwner(targetEntity)
    if not targetPlayer or targetPlayer <= 0 or targetPlayer == attacker then return end

    local currentTime = os.time()
    if not playerDamageTargets[attacker] then
        playerDamageTargets[attacker] = { targets = { [targetPlayer] = true }, timestamp = currentTime }
    else
        local record = playerDamageTargets[attacker]
        if (currentTime - record.timestamp) <= 2 then
            record.targets[targetPlayer] = true
            local targetCount = 0
            for _ in pairs(record.targets) do
                targetCount = targetCount + 1
            end
            if targetCount >= 5 then
                CancelEvent()
                ONLY_AC.Detect(attacker, "Toplu Hasar / Kill-All Hilesi (Mass Damage)", ("2 saniyede %s farklı oyuncuya hasar verildi"):format(targetCount), "ban")
                return
            end
        else
            playerDamageTargets[attacker] = { targets = { [targetPlayer] = true }, timestamp = currentTime }
        end
    end
end)

-- 7. CRASHER SAVUNMASI (Vanity, South & Sound Crasher Filtresi)
if Config.Protections.AntiCrasher then
    -- Ses & Konuşma Spamı ile İstemci Çökertme (Vanity Crasher)
    AddEventHandler("playPedAmbientSpeechEvent", function(sender, data)
        local src = sender
        if not src or src <= 0 then return end
        if ONLY_AC.IsBypass(src) then return end

        local currentTime = os.time()
        if not playerSpeechSpam[src] then
            playerSpeechSpam[src] = { count = 1, timestamp = currentTime }
        else
            local record = playerSpeechSpam[src]
            if (currentTime - record.timestamp) <= 1 then
                record.count = record.count + 1
                if record.count > 12 then
                    CancelEvent()
                    ONLY_AC.Detect(src, "Ses / Konuşma Crasher Saldırısı (Vanity Crasher)", ("1 saniyede %s ambient speech paketi"):format(record.count), "ban")
                    return
                end
            else
                record.count = 1
                record.timestamp = currentTime
            end
        end
    end)
end

-- 8. YASAKLI SİLAH / OBJE TOPLAMA KORUMASI (Anti Weapon Pickup & Money Drop)
if Config.Protections.AntiWeaponPickup or Config.Protections.AntiMoneyDrop then
    AddEventHandler("gameEventTriggered", function(eventName, args)
        if eventName == "CEventNetworkPlayerCollectedPickup" then
            local player = args[1]
            if player and player > 0 and not ONLY_AC.IsBypass(player) then
                if Config.Protections.AntiWeaponPickup then
                    print(("^3[ONLY AC GÜVENLİK]^0 Oyuncu %s şüpheli bir yer pickup'ı topladı."):format(player))
                end
            end
        end
    end)
end

-- Temizlik döngüsü
AddEventHandler("playerDropped", function()
    local src = source
    playerExplosions[src] = nil
    playerEntitySpawns[src] = nil
    playerParticles[src] = nil
    playerPedSpawns[src] = nil
    playerDamageTargets[src] = nil
    playerWeaponPickups[src] = nil
    playerSpeechSpam[src] = nil
end)

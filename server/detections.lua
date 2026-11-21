-- =========================================================================
-- 465 AC v4.2.0 - SUNUCU TARAFLI DÜNYA, CRASHER, OBJE & EVENT KORUMALARI
-- Tek Birleştirilmiş entityCreating, Milisaniye Pencereli Spam & Troll Kalkanı
-- =========================================================================

local rateBuckets = {
    entity = {},
    ped = {},
    vehicle = {},
    explosion = {},
    particle = {},
    speech = {},
    fire = {}
}

-- Tekrarı önleyen ortak milisaniye tabanlı hız sınırı denetleyicisi
local function checkRate(bucketName, src, maxCount, windowSec)
    local nowMs = GetGameTimer()
    local winMs = (windowSec or 5) * 1000
    local bucket = rateBuckets[bucketName]
    local rec = bucket[src]

    if not rec or (nowMs - rec.ts) > winMs then
        bucket[src] = { count = 1, ts = nowMs }
        return false, 1
    end

    rec.count = rec.count + 1
    return rec.count > maxCount, rec.count
end

-- 1. BİRLEŞTİRİLMİŞ ENTITY, PED, ARAÇ SPAWN & MONEY DROP KORUMASI
AddEventHandler("entityCreating", function(entity)
    if not DoesEntityExist(entity) then return end

    local owner = NetworkGetEntityOwner(entity)
    if not owner or owner <= 0 or ONLY_AC.IsBypass(owner) then return end

    -- Yalnızca script/network tarafından üretilen entity'ler (popType >= 6);
    -- OneSync trafik/NPC sahiplik geçişlerini (popType <= 5) asla false-ban yapmaz.
    local popType = GetEntityPopulationType and GetEntityPopulationType(entity) or 6
    if popType <= 5 then return end

    local model = GetEntityModel(entity)
    local entityType = GetEntityType(entity) -- 1: Ped, 2: Vehicle, 3: Object

    -- Güvenli RP obje beyaz listesi
    if Config.ObjectWhitelist and Config.ObjectWhitelist[model] then
        return
    end

    -- Yasaklı para paketi / drop objeleri (AntiMoneyDrop)
    if ONLY_AC_Shared.IsModuleEnabled("AntiMoneyDrop") and Config.MoneyDropModels and Config.MoneyDropModels[model] then
        CancelEvent()
        ONLY_AC.Detect(owner, "Sahte Para / Drop Objesi Engellendi (Anti-MoneyDrop)", ("Model Hash: %s"):format(model), "ban", "AntiMoneyDrop")
        return
    end

    -- Yasaklı model listesi (Prop / Ağır Araç)
    if ONLY_AC_Shared.IsModuleEnabled("AntiEntitySpam") and Config.BlacklistedModels and Config.BlacklistedModels[model] then
        CancelEvent()
        ONLY_AC.Detect(owner, "Yasaklı Model Spawn Girişimi", ("Model Hash: %s"):format(model), "ban", "AntiEntitySpam")
        return
    end

    -- NPC / Ped spam koruması
    if entityType == 1 and ONLY_AC_Shared.IsModuleEnabled("AntiPedSpam") then
        local hit, count = checkRate("ped", owner, Config.MaxPedSpawnsPerWindow or 4, Config.PedWindowSeconds or 5)
        if hit then
            CancelEvent()
            ONLY_AC.Detect(owner, "Toplu NPC Basma (Ped Spam)", ("%s sn içinde %s ped"):format(Config.PedWindowSeconds or 5, count), "ban", "AntiPedSpam")
            return
        end
    end

    -- Araç spawn hız koruması
    if entityType == 2 and ONLY_AC_Shared.IsModuleEnabled("AntiVehicleSpawn") then
        local hit, count = checkRate("vehicle", owner, Config.MaxEntitySpawnsPerWindow or 6, Config.EntityWindowSeconds or 5)
        if hit then
            CancelEvent()
            ONLY_AC.Detect(owner, "Yetkisiz Toplu Araç Spawn (Anti-VehicleSpawn)", ("%s sn içinde %s araç"):format(Config.EntityWindowSeconds or 5, count), "ban", "AntiVehicleSpawn")
            return
        end
    end

    -- Genel entity crasher spam koruması
    if ONLY_AC_Shared.IsModuleEnabled("AntiEntitySpam") then
        local hit, count = checkRate("entity", owner, Config.MaxEntitySpawnsPerWindow or 6, Config.EntityWindowSeconds or 5)
        if hit then
            CancelEvent()
            ONLY_AC.Detect(owner, "Toplu Entity / Obje Spamı (Crasher)", ("%s sn içinde %s entity"):format(Config.EntityWindowSeconds or 5, count), "ban", "AntiEntitySpam")
            return
        end
    end
end)

-- 2. PATLAMA KORUMASI (Yasaklı Patlama Türleri, Büyük Ölçek & Spam)
AddEventHandler("explosionEvent", function(sender, ev)
    local src = sender
    if not src or src <= 0 or ONLY_AC.IsBypass(src) then return end
    if not ONLY_AC_Shared.IsModuleEnabled("AntiExplosionSpam") then return end

    local expType = ev and ev.explosionType
    if Config.BlacklistedExplosions and expType and Config.BlacklistedExplosions[expType] then
        CancelEvent()
        ONLY_AC.Detect(src, "Yasaklı Patlama Türü", ("Patlama Tipi: %s"):format(expType), "ban", "AntiExplosionSpam")
        return
    end

    if ev and ev.damageScale and ev.damageScale > 2.5 then
        CancelEvent()
        ONLY_AC.Detect(src, "Modifiye Patlama Ölçeği (Explosion Damage Scale)", ("Ölçek: %.1f"):format(ev.damageScale), "ban", "AntiExplosionSpam")
        return
    end

    local hit, count = checkRate("explosion", src, Config.MaxExplosionsPerWindow or 3, Config.ExplosionWindowSeconds or 5)
    if hit then
        CancelEvent()
        ONLY_AC.Detect(src, "Toplu Patlama Spamı (Explosion Flood)", ("%s sn içinde %s patlama"):format(Config.ExplosionWindowSeconds or 5, count), "ban", "AntiExplosionSpam")
    end
end)

-- 3. PARTİKÜL / EFEKT SPAM KORUMASI
AddEventHandler("ptFxEvent", function(sender, data)
    local src = sender
    if not src or src <= 0 or ONLY_AC.IsBypass(src) then return end
    if not ONLY_AC_Shared.IsModuleEnabled("AntiParticleSpam") then return end

    if data and data.scale and data.scale > 5.0 then
        CancelEvent()
        ONLY_AC.Detect(src, "Dev Ölçekli Partikül Crasher Girişimi", ("Ölçek: %.1f"):format(data.scale), "kick", "AntiParticleSpam")
        return
    end

    local hit, count = checkRate("particle", src, Config.MaxParticlePerWindow or 4, Config.ParticleWindowSeconds or 3)
    if hit then
        CancelEvent()
        ONLY_AC.Detect(src, "Partikül / Efekt Spamı (FPS Crasher)", ("%s sn içinde %s efekt"):format(Config.ParticleWindowSeconds or 3, count), "kick", "AntiParticleSpam")
    end
end)

-- 4. UZAKTAN OYUNCU DONDURMA KORUMASI (ClearPedTasks)
AddEventHandler("clearPedTasksEvent", function(sender, data)
    local src = sender
    if not src or src <= 0 or ONLY_AC.IsBypass(src) then return end
    if not ONLY_AC_Shared.IsModuleEnabled("AntiClearTasks") then return end

    if data and data.pedId and data.pedId ~= GetPlayerPed(src) then
        CancelEvent()
        ONLY_AC.Detect(src, "Uzaktan Oyuncu Dondurma / Araçtan Atma (ClearPedTasks)", "Başka ped üzerinde yetkisiz görev silme", "ban", "AntiClearTasks")
    end
end)

-- 5. CRASHER & TROLL EVENT SAVUNMASI (Ambient Speech, Fire, Weapon Troll)
AddEventHandler("playPedAmbientSpeechEvent", function(sender, data)
    local src = sender
    if not src or src <= 0 or ONLY_AC.IsBypass(src) then return end
    if not ONLY_AC_Shared.IsModuleEnabled("AntiCrasher") then return end

    local hit, count = checkRate("speech", src, 12, 1)
    if hit then
        CancelEvent()
        ONLY_AC.Detect(src, "Ses / Konuşma Crasher Saldırısı", ("1 saniyede %s paket"):format(count), "ban", "AntiCrasher")
    end
end)

AddEventHandler("fireEvent", function(sender, data)
    local src = sender
    if not src or src <= 0 or ONLY_AC.IsBypass(src) then return end
    if not ONLY_AC_Shared.IsModuleEnabled("AntiCrasher") then return end

    local hit, count = checkRate("fire", src, 8, 3)
    if hit then
        CancelEvent()
        ONLY_AC.Detect(src, "Toplu Yangın Çıkarma / Fire Crasher", ("3 sn içinde %s ateş"):format(count), "kick", "AntiCrasher")
    end
end)

AddEventHandler("giveWeaponEvent", function(sender, data)
    local src = sender
    if not src or src <= 0 or ONLY_AC.IsBypass(src) then return end
    if not ONLY_AC_Shared.IsModuleEnabled("AntiBlacklistedWeapons") then return end

    if data and ((data.pedId and data.pedId ~= GetPlayerPed(src)) or (data.weaponType and Config.BlacklistedWeapons and Config.BlacklistedWeapons[data.weaponType])) then
        CancelEvent()
        ONLY_AC.Detect(src, "Yetkisiz Ağ Silah Verme / Yasaklı Silah (GiveWeaponEvent)", ("Silah Hash: %s"):format(tostring(data.weaponType)), "ban", "AntiBlacklistedWeapons")
    end
end)

AddEventHandler("removeAllWeaponsEvent", function(sender, data)
    local src = sender
    if not src or src <= 0 or ONLY_AC.IsBypass(src) then return end
    if not ONLY_AC_Shared.IsModuleEnabled("AntiCrasher") then return end

    if data and data.pedId and data.pedId ~= GetPlayerPed(src) then
        CancelEvent()
        ONLY_AC.Detect(src, "Uzaktan Silah Silme Trolü (RemoveAllWeaponsEvent)", "Başka oyuncunun silahlarını silme girişimi", "ban", "AntiCrasher")
    end
end)

-- 6. ARAÇ MAGNETO / SÜRÜCÜLÜ ARAÇ ÇEKME KONTROLÜ
AddEventHandler("requestControlEvent", function(sender, entityNetId)
    local src = sender
    if not src or src <= 0 or ONLY_AC.IsBypass(src) then return end
    if not ONLY_AC_Shared.IsModuleEnabled("AntiVehicleMagneto") then return end
    if not entityNetId or entityNetId <= 0 then return end

    local entity = NetworkGetEntityFromNetworkId(entityNetId)
    if DoesEntityExist(entity) and GetEntityType(entity) == 2 then
        local driver = GetPedInVehicleSeat(entity, -1)
        if driver and driver ~= 0 and IsPedAPlayer(driver) and driver ~= GetPlayerPed(src) then
            local dist = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(entity))
            if dist > 45.0 then
                CancelEvent()
                ONLY_AC.Detect(src, "Uzaktan Araç Kontrolü / Magneto Saldırısı", ("Sürücülü araca %.1fm uzaktan müdahale"):format(dist), "kick", "AntiVehicleMagneto")
            end
        end
    end
end)

-- 7. PICKUP TOPLAMA İZLEME
AddEventHandler("gameEventTriggered", function(eventName, args)
    if eventName == "CEventNetworkPlayerCollectedPickup" and args and args[1] then
        local player = args[1]
        if player and player > 0 and not ONLY_AC.IsBypass(player) then
            if ONLY_AC_Shared.IsModuleEnabled("AntiWeaponPickup") then
                print(("^3[465 AC GÜVENLİK]^0 Oyuncu %s yerden pickup topladı (Type/Args kaydedildi)."):format(player))
            end
        end
    end
end)

AddEventHandler("playerDropped", function()
    local src = source
    for _, bucket in pairs(rateBuckets) do
        bucket[src] = nil
    end
end)

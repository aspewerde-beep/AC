-- =========================================================================
-- 465 AC v4.2.0 - SUNUCU TARAFLI SAVAŞ & HASAR DOĞRULAMA MOTORU
-- Milisaniye Rate-Limit, Ağır Silah Sınıf Toleransı, Mass-Kill & Magic Bullet
-- =========================================================================

local playerDamageHistory = {}
local playerHeadshots = {}
local playerHitTargets = {}

local MELEE_WEAPONS = {
    [`WEAPON_UNARMED`] = true, [`WEAPON_KNIFE`] = true, [`WEAPON_BAT`] = true,
    [`WEAPON_DAGGER`] = true, [`WEAPON_MACHETE`] = true, [`WEAPON_SWITCHBLADE`] = true,
    [`WEAPON_KNUCKLE`] = true, [`WEAPON_NIGHTSTICK`] = true, [`WEAPON_CROWBAR`] = true,
    [`WEAPON_GOLFCLUB`] = true, [`WEAPON_HAMMER`] = true, [`WEAPON_HATCHET`] = true
}

local HEAVY_DMG_WEAPONS = {
    [`WEAPON_SNIPERRIFLE`] = true, [`WEAPON_HEAVYSNIPER`] = true, [`WEAPON_HEAVYSNIPER_MK2`] = true,
    [`WEAPON_MARKSMANRIFLE`] = true, [`WEAPON_MARKSMANRIFLE_MK2`] = true, [`WEAPON_MUSKET`] = true,
    [`WEAPON_PUMPSHOTGUN`] = true, [`WEAPON_PUMPSHOTGUN_MK2`] = true, [`WEAPON_SAWNOFFSHOTGUN`] = true,
    [`WEAPON_DBSHOTGUN`] = true, [`WEAPON_HEAVYSHOTGUN`] = true
}

local SNIPER_WEAPONS = {
    [`WEAPON_SNIPERRIFLE`] = true, [`WEAPON_HEAVYSNIPER`] = true, [`WEAPON_HEAVYSNIPER_MK2`] = true
}

AddEventHandler("weaponDamageEvent", function(sender, data)
    local attacker = sender
    if not attacker or attacker <= 0 or not data then return end
    if ONLY_AC.IsBypass(attacker) then return end

    if not data.hitGlobalId or data.hitGlobalId <= 0 then return end
    local targetEntity = NetworkGetEntityFromNetworkId(data.hitGlobalId)
    if not DoesEntityExist(targetEntity) then return end

    local attackerPed = GetPlayerPed(attacker)
    if not DoesEntityExist(attackerPed) or attackerPed == targetEntity then return end

    -- Ölü oyuncuya hasar girişimini engelle
    if IsEntityDead(targetEntity) or GetEntityHealth(targetEntity) <= 0 then
        CancelEvent()
        return
    end

    local damage = tonumber(data.weaponDamage) or 0
    local weaponType = data.weaponType
    local nowMs = GetGameTimer()
    local isMelee = MELEE_WEAPONS[weaponType] == true

    -- 1. TOPLU OYUNCU / HEDEF KATLİAMI (AntiMassKill - 1500ms penceresi)
    if ONLY_AC_Shared.IsModuleEnabled("AntiMassKill") and IsPedAPlayer(targetEntity) then
        local mRec = playerHitTargets[attacker]
        if not mRec or (nowMs - mRec.ts) > 1500 then
            playerHitTargets[attacker] = { targets = { [targetEntity] = true }, count = 1, ts = nowMs }
        else
            if not mRec.targets[targetEntity] then
                mRec.targets[targetEntity] = true
                mRec.count = mRec.count + 1
                if mRec.count >= 4 then
                    CancelEvent()
                    ONLY_AC.Detect(attacker, "Toplu Hasar / Kill-All Hilesi (AntiMassKill)", ("1.5 saniyede %s farklı oyuncuya hasar"):format(mRec.count), "ban", "AntiMassKill")
                    return
                end
            end
        end
    end

    -- 2. HASAR SIKLIĞI / RAPİD FİRE SUNUCU KORUMASI (1000ms penceresi)
    if ONLY_AC_Shared.IsModuleEnabled("AntiRapidFire") then
        local dRec = playerDamageHistory[attacker]
        if not dRec or (nowMs - dRec.ts) > 1000 then
            playerDamageHistory[attacker] = { count = 1, ts = nowMs }
        else
            dRec.count = dRec.count + 1
            if dRec.count > 9 then
                CancelEvent()
                ONLY_AC.Detect(attacker, "Sunucu Taraflı Hasar / Rapid Fire Spam", ("1 saniyede %s hasar paketi"):format(dRec.count), "ban", "AntiRapidFire")
                return
            end
        end
    end

    -- 3. HASAR ÇARPANI KONTROLÜ (AntiDamageModifier)
    if ONLY_AC_Shared.IsModuleEnabled("AntiDamageModifier") then
        if isMelee and damage > (Config.MaxMeleeDamage or 95) then
            CancelEvent()
            ONLY_AC.Detect(attacker, "Aşırı Yakın Dövüş Hasarı (One-Punch Kill)", ("Hasar: %s"):format(damage), "ban", "AntiDamageModifier")
            return
        end

        local maxAllowed = HEAVY_DMG_WEAPONS[weaponType] and (Config.MaxHeavyWeaponDamage or 250) or (Config.MaxWeaponDamage or 165)
        if not isMelee and damage > maxAllowed then
            CancelEvent()
            ONLY_AC.Detect(attacker, "Aşırı Silah Hasarı (Damage Modifier / RPF)", ("Hasar: %s | Silah: %s"):format(damage, tostring(weaponType)), "ban", "AntiDamageModifier")
            return
        end
    end

    -- 4. İMKANSIZ MESAFE (Magic Bullet / AntiImpossibleDamage)
    if ONLY_AC_Shared.IsModuleEnabled("AntiImpossibleDamage") then
        local distance = #(GetEntityCoords(attackerPed) - GetEntityCoords(targetEntity))
        if isMelee and distance > 6.5 then
            CancelEvent()
            ONLY_AC.Detect(attacker, "İmkansız Yakın Dövüş Mesafesi", ("Mesafe: %.2fm"):format(distance), "ban", "AntiImpossibleDamage")
            return
        end
        if not isMelee and distance > (Config.MaxShootDistance or 260.0) then
            CancelEvent()
            ONLY_AC.Detect(attacker, "İmkansız Vuruş Mesafesi (Magic Bullet)", ("Mesafe: %.2fm"):format(distance), "ban", "AntiImpossibleDamage")
            return
        end
    end

    -- 5. HEADSHOT ORANI TAKİBİ (Aimbot Destek Analizi)
    if ONLY_AC_Shared.IsModuleEnabled("AntiAimbot") and not isMelee and IsPedAPlayer(targetEntity) then
        local isHeadshot = (data.headShot == true) or (data.hitComponent == 0)
        playerHeadshots[attacker] = playerHeadshots[attacker] or {}
        table.insert(playerHeadshots[attacker], isHeadshot)
        if #playerHeadshots[attacker] > 10 then
            table.remove(playerHeadshots[attacker], 1)
        end

        if #playerHeadshots[attacker] >= 10 then
            local headshotCount = 0
            for _, hs in ipairs(playerHeadshots[attacker]) do
                if hs then headshotCount = headshotCount + 1 end
            end
            if headshotCount >= 9 and not SNIPER_WEAPONS[weaponType] then
                playerHeadshots[attacker] = {}
                ONLY_AC.Detect(attacker, "Aşırı Yüksek Headshot Oranı (Aimbot)", ("Son 10 isabette %s headshot"):format(headshotCount), "ban", "AntiAimbot")
            end
        end
    end
end)

AddEventHandler("playerDropped", function()
    local src = source
    playerDamageHistory[src] = nil
    playerHeadshots[src] = nil
    playerHitTargets[src] = nil
end)

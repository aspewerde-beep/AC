-- =========================================================================
-- ONLY AC v4.1.0 (ENTERPRISE EDITION) - SUNUCU TARAFLI SAVAŞ & HASAR KORUMASI
-- Standartlar: FeloxAC v4.1, Echo Standartları (Silent Aim, Wallbang, Mass Kill, RPF)
-- =========================================================================

local playerDamageHistory = {}   -- Oyuncu saniyelik hasar sıklığı (Rate limit)
local playerHeadshots = {}       -- Son vuruşların headshot oranı takibi
local playerHitTargets = {}      -- Kısa sürede farklı hedeflere vurma (Mass Kill) analizi

if Config.Protections.AntiImpossibleDamage or Config.Protections.AntiDamageModifier or Config.Protections.AntiMassKill then
    AddEventHandler("weaponDamageEvent", function(sender, data)
        local attacker = sender
        if not attacker or attacker <= 0 then return end

        -- Bypass kontrolü
        if ONLY_AC.IsBypass(attacker) then return end

        local targetEntity = NetworkGetEntityFromNetworkId(data.hitGlobalId)
        if not DoesEntityExist(targetEntity) then return end

        local attackerPed = GetPlayerPed(attacker)
        if not DoesEntityExist(attackerPed) then return end

        -- 1. KENDİNE HASAR KONTROLÜ (Self-Harm / İntihar / Kendi bombası vs.)
        if attackerPed == targetEntity then
            return
        end

        -- 2. ÖLÜ OYUNCUYA HASAR KONTROLÜ (Corpse Hit / Exploit)
        if IsEntityDead(targetEntity) or GetEntityHealth(targetEntity) <= 0 then
            CancelEvent()
            return
        end

        local damage = data.weaponDamage
        local weaponType = data.weaponType
        local currentTime = os.time()

        -- 3. TOPLU OYUNCU VURMA (MASS KILL / KILL-ALL) KORUMASI
        if Config.Protections.AntiMassKill then
            if not playerHitTargets[attacker] then
                playerHitTargets[attacker] = { targets = { [targetEntity] = true }, count = 1, timestamp = currentTime }
            else
                local mRecord = playerHitTargets[attacker]
                if (currentTime - mRecord.timestamp) <= 1.5 then
                    if not mRecord.targets[targetEntity] then
                        mRecord.targets[targetEntity] = true
                        mRecord.count = mRecord.count + 1
                        -- 1.5 saniyede 3'ten fazla farklı hedefe tek mermide hasar veriyorsa
                        if mRecord.count >= 3 then
                            CancelEvent()
                            ONLY_AC.Detect(attacker, "Toplu Hasar / Katliam Hilesi (Mass Kill / Kill-All)", ("1.5 saniyede %s farklı hedefe hasar verildi"):format(mRecord.count), "ban")
                            return
                        end
                    end
                else
                    playerHitTargets[attacker] = { targets = { [targetEntity] = true }, count = 1, timestamp = currentTime }
                end
            end
        end

        -- 4. RATE LIMITING (Saniyede Aşırı Hasar Olayı / Seri Hasar)
        if not playerDamageHistory[attacker] then
            playerDamageHistory[attacker] = { count = 1, timestamp = currentTime }
        else
            local dRecord = playerDamageHistory[attacker]
            if (currentTime - dRecord.timestamp) < 1 then
                dRecord.count = dRecord.count + 1
                if dRecord.count > 6 then
                    CancelEvent()
                    ONLY_AC.Detect(attacker, "Aşırı Hasar Sıklığı (Rapid Fire / Damage Spam)", ("1 saniyede %s hasar olayı"):format(dRecord.count), "ban")
                    return
                end
            else
                dRecord.count = 1
                dRecord.timestamp = currentTime
            end
        end

        -- 5. YUMRUK / BIÇAK (MELEE) AŞIRI HASAR KONTROLÜ
        local isMelee = (weaponType == `WEAPON_UNARMED` or weaponType == `WEAPON_KNIFE` or weaponType == `WEAPON_BAT` or weaponType == `WEAPON_DAGGER` or weaponType == `WEAPON_MACHETE` or weaponType == `WEAPON_SWITCHBLADE`)
        if isMelee and damage > (Config.MaxMeleeDamage or 95) then
            CancelEvent()
            ONLY_AC.Detect(attacker, "Aşırı Yakın Dövüş Hasarı (One-Punch Kill)", ("Hasar: %s | Silah: %s"):format(damage, weaponType), "ban")
            return
        end

        -- 6. AŞIRI SİLAH HASARI KONTROLÜ (Damage Multiplier / Anti-RPF)
        if not isMelee and damage > (Config.MaxWeaponDamage or 160) then
            CancelEvent()
            ONLY_AC.Detect(attacker, "Aşırı Silah Hasarı (Weapon Damage Modifier / RPF)", ("Hasar: %s | Silah: %s"):format(damage, weaponType), "ban")
            return
        end

        -- 7. İMKANSIZ MESAFE (MAGIC BULLET) KONTROLÜ
        local attackerCoords = GetEntityCoords(attackerPed)
        local targetCoords = GetEntityCoords(targetEntity)
        local distance = #(attackerCoords - targetCoords)

        -- Yakın dövüş için mesafe kontrolü (5.5 metreden uzak olamaz)
        if isMelee and distance > 5.5 then
            CancelEvent()
            ONLY_AC.Detect(attacker, "İmkansız Yakın Dövüş Mesafesi", ("Mesafe: %.2fm"):format(distance), "ban")
            return
        end

        -- Ateşli silah için mesafe kontrolü
        if not isMelee and distance > (Config.MaxShootDistance or 250.0) then
            CancelEvent()
            ONLY_AC.Detect(attacker, "İmkansız Vuruş Mesafesi (Magic Bullet)", ("Mesafe: %.2fm"):format(distance), "ban")
            return
        end

        -- 8. DUVAR ARKASINDAN VURMA (WALLBANG / LINE OF SIGHT) KONTROLÜ
        if not isMelee and distance > 10.0 then
            pcall(function()
                if HasEntityClearLosToEntity then
                    local hasLos = HasEntityClearLosToEntity(attackerPed, targetEntity, 17)
                    if hasLos == 0 or hasLos == false then
                        if weaponType ~= `WEAPON_HEAVYSNIPER` and weaponType ~= `WEAPON_HEAVYSNIPER_MK2` then
                            ONLY_AC.Detect(attacker, "Duvar Arkasından Vurma Şüphesi (Wallbang / No LOS)", ("Mesafe: %.1fm | Silah: %s"):format(distance, weaponType), "kick")
                        end
                    end
                end
            end)
        end

        -- 9. HEADSHOT ORANI TAKİBİ (Aimbot Şüphesi)
        local isHeadshot = (data.headShot == true) or (data.hitComponent == 0)
        if not isMelee then
            if not playerHeadshots[attacker] then
                playerHeadshots[attacker] = {}
            end
            table.insert(playerHeadshots[attacker], isHeadshot)
            if #playerHeadshots[attacker] > 10 then
                table.remove(playerHeadshots[attacker], 1)
            end

            if #playerHeadshots[attacker] >= 10 then
                local headshotCount = 0
                for _, hs in ipairs(playerHeadshots[attacker]) do
                    if hs then headshotCount = headshotCount + 1 end
                end

                -- 10 vuruşun 9 veya daha fazlası headshot ise ve dürbünlü sniper değilse
                if headshotCount >= 9 and weaponType ~= `WEAPON_SNIPERRIFLE` and weaponType ~= `WEAPON_HEAVYSNIPER` and weaponType ~= `WEAPON_HEAVYSNIPER_MK2` then
                    ONLY_AC.Detect(attacker, "Aşırı Yüksek Headshot Oranı (Silent Aimbot Şüphesi)", ("10 atışta %s kafa vuruşu"):format(headshotCount), "ban")
                    playerHeadshots[attacker] = {}
                    return
                end
            end
        end
    end)
end

-- Ayrılan oyuncuların tablolarını temizle
AddEventHandler("playerDropped", function()
    local src = source
    playerDamageHistory[src] = nil
    playerHeadshots[src] = nil
    playerHitTargets[src] = nil
end)

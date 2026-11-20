-- =========================================================================
-- ONLY AC v4.1.0 (ENTERPRISE EDITION) - İLERİ SEVİYE İSTEMCİ HİLE TESPİTLERİ
-- Standartlar: FeloxAC v4.1, Echo & Phoenix Entegrasyonu
-- =========================================================================

-- Kritik Native Fonksiyonlarının Bellek Klonları (Native Hooking Koruması)
local _GetEntityCoords = GetEntityCoords
local _GetEntityHealth = GetEntityHealth
local _GetPlayerInvincible = GetPlayerInvincible
local _SetEntityVelocity = SetEntityVelocity
local _GetEntityVelocity = GetEntityVelocity
local _IsEntityDead = IsEntityDead

CreateThread(function()
    -- Ana sistemin handshake tamamlamasını bekle
    while not ONLY_AC_Client.IsReady() do
        Wait(500)
    end

    local playerId = PlayerId()
    local lastCoords = _GetEntityCoords(PlayerPedId())
    local lastHealth = _GetEntityHealth(PlayerPedId())
    local lastShotTime = 0

    -- Spawn / Yükleme Ekranı Koruma Zamanlayıcısı (Grace Period)
    local spawnGraceEndTime = GetGameTimer() + ((Config.SpawningGracePeriodSeconds or 15) * 1000)

    -- Oyuncu tekrar doğarsa (Revive / Respawn) grace period yenile
    AddEventHandler("playerSpawned", function()
        spawnGraceEndTime = GetGameTimer() + ((Config.SpawningGracePeriodSeconds or 15) * 1000)
    end)

    -- Bölge Muafiyeti Kontrolü (Exclude Zones)
    local function IsInExcludeZone(coords)
        if not Config.Protections.UseExcludeZones or not Config.ExcludeZones then return false end
        for _, zone in ipairs(Config.ExcludeZones) do
            if #(coords - zone.coords) <= zone.radius then
                return true, zone.name
            end
        end
        return false
    end

    -- =====================================================================
    -- 0. NATIVE HOOK & DEVTOOLS KORUMASI (Anti Native Hook & NUI Guard)
    -- =====================================================================
    CreateThread(function()
        if not Config.Protections.AntiNativeHook then return end

        while true do
            Wait(3500)
            -- 1. Fonksiyon Tipi ve Debug Info Kontrolü
            local checkNatives = {
                { fn = GetEntityCoords, name = "GetEntityCoords" },
                { fn = GetEntityHealth, name = "GetEntityHealth" },
                { fn = SetPlayerInvincible, name = "SetPlayerInvincible" }
            }

            for _, item in ipairs(checkNatives) do
                local info = debug.getinfo(item.fn)
                if info and (info.what ~= "C" or (info.source and info.source ~= "=[C]")) then
                    ONLY_AC_Client.Report("Lua Native Hook Tespiti (Anti Native Hook)", ("Kritik native manipüle edildi: %s (Type: %s)"):format(item.name, info.what))
                    break
                end
            end

            -- 2. Global vs Klon Karşılaştırması
            local currentPed = PlayerPedId()
            if DoesEntityExist(currentPed) then
                local c1 = _GetEntityCoords(currentPed)
                local c2 = GetEntityCoords(currentPed)
                if #(c1 - c2) > 2.0 then
                    ONLY_AC_Client.Report("Koordinat Spoofing / Native Hook", ("Klon ile Global koordinat uyuşmuyor: %.1f fark"):format(#(c1 - c2)))
                end
            end
        end
    end)

    -- =====================================================================
    -- 0.1 NUI DEVTOOLS & EXECUTOR ENJEKSİYON KORUMASI (FeloxAC v4.1.105)
    -- =====================================================================
    CreateThread(function()
        if not Config.Protections.AntiNUIDevTools then return end

        while true do
            Wait(3000)
            pcall(function()
                -- Bilinen global executor değişkenlerini denetle (RedEngine, Eulen, Susano, Lumia, 465LOL vb.)
                local suspiciousGlobals = {
                    "RedEngine", "eulen", "Susano", "Lumia", "Nexus", "Macho",
                    "LynxMenu", "TiagoModz", "HamHaxia", "Fendr", "Dopamine",
                    "465LOL", "fourSixFive", "LOL465", "_465LOL"
                }

                for _, gVar in ipairs(suspiciousGlobals) do
                    if _G[gVar] ~= nil then
                        ONLY_AC_Client.Report("Hile Menüsü Değişkeni Tespiti (Global Executor Variable)", ("Aktif Menü: %s"):format(gVar))
                        break
                    end
                end
            end)
        end
    end)

    -- =====================================================================
    -- 1. SİLAH, VİZYON, GÖRÜNMEZLİK & HASAR MODLARI (1.5 Saniyede Bir)
    -- =====================================================================
    CreateThread(function()
        while true do
            Wait(1500)
            local ped = PlayerPedId()

            if DoesEntityExist(ped) and not _IsEntityDead(ped) then
                -- Yasaklı Ağır Silah Kontrolü
                if Config.Protections.AntiBlacklistedWeapons then
                    for weaponHash, _ in pairs(Config.BlacklistedWeapons) do
                        if HasPedGotWeapon(ped, weaponHash, false) then
                            RemoveAllPedWeapons(ped, true)
                            ONLY_AC_Client.Report("Yasaklı Silah Tespiti", ("Silah Hash: %s"):format(weaponHash))
                            break
                        end
                    end
                end

                -- Hasar Çarpanı Kontrolü (Damage Modifier Hack / One-shot)
                if Config.Protections.AntiDamageModifier then
                    local weaponMod = GetPlayerWeaponDamageModifier(playerId)
                    local meleeMod = GetPlayerMeleeWeaponDamageModifier(playerId)
                    if weaponMod > 1.05 then
                        ONLY_AC_Client.Report("Silah Hasar Artırma Hilesi (Weapon Damage Modifier)", ("Çarpan: %.2f"):format(weaponMod))
                    end
                    if meleeMod > 1.05 then
                        ONLY_AC_Client.Report("Yumruk Hasar Artırma Hilesi (Melee Damage Modifier)", ("Çarpan: %.2f"):format(meleeMod))
                    end
                end

                -- Görünmezlik Kontrolü (Invisibility / Ghostmode)
                if Config.Protections.AntiInvisibility then
                    local isVisible = IsEntityVisible(ped)
                    local alpha = GetEntityAlpha(ped)
                    if not isVisible or alpha < 50 then
                        ONLY_AC_Client.Report("Görünmezlik Hilesi (Invisibility / Alpha)", ("Visible: %s | Alpha: %s"):format(tostring(isVisible), alpha))
                    end
                end

                -- Süper Zıplama Kontrolü (Super Jump)
                if Config.Protections.AntiSuperJump then
                    if IsPedDoingSuperJump(playerId) then
                        ONLY_AC_Client.Report("Süper Zıplama Hilesi (Super Jump)", "IsPedDoingSuperJump aktif")
                    end
                end

                -- Duvarlardan Geçme (No-Collision)
                if Config.Protections.AntiNoCollision then
                    if GetEntityCollisionDisabled(ped) then
                        ONLY_AC_Client.Report("Çarpışma Devredışı (No-Collision)", "GetEntityCollisionDisabled aktif")
                    end
                end

                -- Termal ve Gece Görüşü Kontrolü
                if Config.Protections.AntiNightThermalVision then
                    if GetUsingnightvision() then
                        SetNightvision(false)
                        ONLY_AC_Client.Report("Gece Görüşü (Nightvision) Hilesi", "Yetkisiz vizyon modu")
                    end
                    if GetUsingseethrough() then
                        SetSeethrough(false)
                        ONLY_AC_Client.Report("Termal Görüş (Thermalvision) Hilesi", "Yetkisiz vizyon modu")
                    end
                end

                -- Freecam / Spectate Kontrolü
                if Config.Protections.AntiSpectate then
                    if NetworkIsInSpectatorMode() then
                        ONLY_AC_Client.Report("Yetkisiz İzleyici Modu (Spectate / Freecam)", "NetworkIsInSpectatorMode aktif")
                    end
                end
            end
        end
    end)

    -- =====================================================================
    -- 2. HIZ, NOCLIP, IŞINLANMA, GROUND NOCLIP & FIRLATMA (ANTI-LAUNCH)
    -- =====================================================================
    CreateThread(function()
        while true do
            Wait(1000)
            local ped = PlayerPedId()

            if DoesEntityExist(ped) and not _IsEntityDead(ped) and not IsPedInParachuteFreeFall(ped) and not IsPedFalling(ped) then
                local currentCoords = _GetEntityCoords(ped)
                local distance = #(currentCoords - lastCoords)
                local inVehicle = IsPedInAnyVehicle(ped, false)
                local isSpawning = GetGameTimer() < spawnGraceEndTime
                local inExcludeZone, zoneName = IsInExcludeZone(currentCoords)

                -- 1. Teleport Kontrolü (Bölge Muafiyeti ve Grace Period ile)
                if Config.Protections.AntiTeleport and not isSpawning and not inExcludeZone then
                    if distance > (Config.MaxTeleportDistance or 85.0) then
                        if GetInteriorFromEntity(ped) == 0 then
                            ONLY_AC_Client.Report("Işınlanma (Teleport) Tespiti", ("1 saniyede %.2f metre atlandı"):format(distance))
                        end
                    end
                end

                -- 2. Yaya Kontrolleri
                if not inVehicle and not IsPedRagdoll(ped) then
                    -- Yaya Speedhack
                    if Config.Protections.AntiSpeedHack and not isSpawning and not inExcludeZone then
                        if distance > (Config.MaxFootSpeed or 16.0) then
                            ONLY_AC_Client.Report("Yaya Hız Hilesi (SpeedHack)", ("Hız: %.2f m/s"):format(distance))
                        end
                    end

                    -- Klasik Noclip (Havada uçma)
                    if Config.Protections.AntiNoclip and not isSpawning and not inExcludeZone then
                        local heightAboveGround = GetEntityHeightAboveGround(ped)
                        if heightAboveGround > 4.0 and distance > 14.0 and not IsPedClimbing(ped) and not IsPedDiving(ped) then
                            ONLY_AC_Client.Report("Uçma Hilesi (Noclip / Fly)", ("Yükseklik: %.2fm | Hız: %.2f m/s"):format(heightAboveGround, distance))
                        end
                    end

                    -- Yerde Yürüyormuş Gibi Gösteren Noclip Bypass (Ground Noclip)
                    if Config.Protections.AntiGroundNoclip and not isSpawning and not inExcludeZone then
                        local speed = GetEntitySpeed(ped)
                        if speed > 18.5 and not IsPedFalling(ped) and not IsPedRagdoll(ped) then
                            ONLY_AC_Client.Report("Yerde Yürüyüş Noclip Hilesi (Ground Noclip Bypass)", ("Hız: %.2f m/s"):format(speed))
                        end
                    end

                    -- Oyuncuyu Gökyüzüne Fırlatma Koruması (Anti-Launch Player)
                    if Config.Protections.AntiLaunchPlayer and not isSpawning then
                        local vel = _GetEntityVelocity(ped)
                        if vel.z > (Config.MaxPlayerZVelocity or 32.0) then
                            _SetEntityVelocity(ped, 0.0, 0.0, 0.0)
                            ONLY_AC_Client.Report("Karakter Fırlatma Hilesi (Anti-Launch Player)", ("Dikey Z İvmesi: %.2f m/s"):format(vel.z))
                        end
                    end

                -- 3. Araç Kontrolleri
                elseif inVehicle then
                    local veh = GetVehiclePedIsIn(ped, false)
                    if DoesEntityExist(veh) then
                        local vehClass = GetVehicleClass(veh)
                        local isAircraft = (vehClass == 15 or vehClass == 16 or vehClass == 14)

                        -- Araç Hız Kontrolü
                        if Config.Protections.AntiSpeedHack and not inExcludeZone then
                            local speedKMH = GetEntitySpeed(veh) * 3.6
                            if speedKMH > (Config.MaxVehicleSpeedKMH or 350.0) then
                                ONLY_AC_Client.Report("Aşırı Araç Hızı (Vehicle Speed Modifier)", ("Hız: %.2f km/s"):format(speedKMH))
                            end
                        end

                        -- Araç Uçurma / Car Fly Koruması
                        if Config.Protections.AntiVehicleFly and not isAircraft and not inExcludeZone then
                            local heightAboveGround = GetEntityHeightAboveGround(veh)
                            local speed = GetEntitySpeed(veh)
                            if heightAboveGround > 25.0 and speed > 25.0 and IsEntityInAir(veh) then
                                ONLY_AC_Client.Report("Araç Uçurma Hilesi (Car Fly / Magneto)", ("Yükseklik: %.2fm | Hız: %.2f m/s"):format(heightAboveGround, speed))
                            end
                        end

                        -- Araç Fırlatma Koruması (Anti-Launch Vehicle)
                        if Config.Protections.AntiLaunchVehicle and not isAircraft then
                            local vehVel = _GetEntityVelocity(veh)
                            if vehVel.z > (Config.MaxVehicleZVelocity or 38.0) then
                                _SetEntityVelocity(veh, 0.0, 0.0, 0.0)
                                ONLY_AC_Client.Report("Araç Fırlatma Hilesi (Anti-Launch Vehicle)", ("Dikey Z İvmesi: %.2f m/s"):format(vehVel.z))
                            end
                        end

                        -- Araç Ölümsüzlük & Hasar Almama
                        if Config.Protections.AntiVehicleGodmode then
                            if not GetEntityCanBeDamaged(veh) then
                                SetEntityCanBeDamaged(veh, true)
                                ONLY_AC_Client.Report("Araç Ölümsüzlüğü (Vehicle Godmode)", "Araç hasar almama aktif")
                            end
                        end
                    end
                end

                lastCoords = currentCoords
            else
                lastCoords = _GetEntityCoords(ped)
            end
        end
    end)

    -- =====================================================================
    -- 3. ÖLÜMSÜZLÜK, LEGİT GODMODE & NO-RAGDOLL (2 Saniyede Bir)
    -- =====================================================================
    CreateThread(function()
        while true do
            Wait(2000)
            local ped = PlayerPedId()

            if DoesEntityExist(ped) and not _IsEntityDead(ped) then
                local currentHealth = _GetEntityHealth(ped)

                -- Native Godmode Kontrolü
                if Config.Protections.AntiGodmode then
                    if _GetPlayerInvincible(playerId) then
                        SetPlayerInvincible(playerId, false)
                        ONLY_AC_Client.Report("Ölümsüzlük Hilesi (Native Godmode)", "GetPlayerInvincible aktif")
                    end

                    if not GetEntityCanBeDamaged(ped) then
                        SetEntityCanBeDamaged(ped, true)
                        ONLY_AC_Client.Report("Hasar Almama Hilesi (Demi-God / Invincible)", "Entity can not be damaged")
                    end
                end

                -- Legit Godmode / Anlık Can Fulleyen Hile Kontrolü
                if Config.Protections.AntiLegitGodmode then
                    if lastHealth < 130 and currentHealth >= 195 and not _IsEntityDead(ped) then
                        ONLY_AC_Client.Report("Hızlı Can Doldurma Hilesi (Legit Godmode / Health Regen)", ("Eski Can: %s -> Yeni Can: %s"):format(lastHealth, currentHealth))
                    end
                end

                -- Anti-Taser / No-Ragdoll Kontrolü
                if Config.Protections.AntiRagdoll then
                    if IsPedBeingStunned(ped, 0) and not IsPedRagdoll(ped) then
                        ONLY_AC_Client.Report("Taser / Ragdoll Koruması Hilesi (No-Ragdoll)", "Taser etkisi altındayken yere düşmeme")
                    end
                end

                lastHealth = currentHealth
            else
                lastHealth = _GetEntityHealth(ped)
            end
        end
    end)

    -- =====================================================================
    -- 4. TROLL OBJE YAPIŞTIRMA KORUMASI (ANTI-ATTACH TROLL)
    -- =====================================================================
    CreateThread(function()
        if not Config.Protections.AntiAttach then return end

        while true do
            Wait(2000)
            local ped = PlayerPedId()

            if DoesEntityExist(ped) and not _IsEntityDead(ped) then
                local attachedEntity = GetEntityAttachedTo(ped)
                if attachedEntity and attachedEntity > 0 and DoesEntityExist(attachedEntity) then
                    local model = GetEntityModel(attachedEntity)
                    -- Eğer obje whitelist içinde değilse yapıştırmayı boz ve sil
                    if not Config.ObjectWhitelist or not Config.ObjectWhitelist[model] then
                        DetachEntity(ped, true, true)
                        DeleteEntity(attachedEntity)
                        ONLY_AC_Client.Report("Troll Obje Yapıştırma Engellendi (Anti-Attach)", ("Model Hash: %s"):format(model))
                    end
                end
            end
        end
    end)

    -- =====================================================================
    -- 5. SERİ ATEŞ & SINIRSIZ ŞARJÖR KONTROLÜ
    -- =====================================================================
    CreateThread(function()
        while true do
            Wait(5)
            local ped = PlayerPedId()

            if IsPedShooting(ped) then
                local currentTime = GetGameTimer()

                -- Rapid Fire Kontrolü
                if Config.Protections.AntiRapidFire then
                    local timeDiff = currentTime - lastShotTime
                    local _, currentWeapon = GetCurrentPedWeapon(ped, true)
                    if timeDiff < 60 and currentWeapon ~= `WEAPON_MICROSMG` and currentWeapon ~= `WEAPON_MINIGUN` then
                        ONLY_AC_Client.Report("Seri Ateş Hilesi (Rapid Fire)", ("Ateş Aralığı: %s ms"):format(timeDiff))
                    end
                end

                -- Sınırsız Mermi Kontrolü (Infinite Ammo)
                if Config.Protections.AntiInfiniteAmmo then
                    local _, currentWeapon = GetCurrentPedWeapon(ped, true)
                    local maxClip = GetMaxAmmoInClip(ped, currentWeapon, true)
                    local _, ammoInClip = GetAmmoInClip(ped, currentWeapon)
                    if ammoInClip > maxClip and maxClip > 0 then
                        ONLY_AC_Client.Report("Sınırsız Şarjör Hilesi (Infinite Clip / Ammo)", ("Şarjördeki: %s | Max: %s"):format(ammoInClip, maxClip))
                    end
                end

                lastShotTime = currentTime
            end
        end
    end)

    -- =====================================================================
    -- 6. AİMBOT TESPİTİ (Kamera Açısı Snap Analizi)
    -- =====================================================================
    CreateThread(function()
        if not Config.Protections.AntiAimbot then return end
        local prevRot = nil
        local shotWindow = {}
        local maxWindow = Config.AimbotCheckWindow or 5
        local maxSnaps = Config.AimbotSnapCount or 4
        local threshold = Config.AimbotAngleThreshold or 15.0

        while true do
            Wait(5)
            local ped = PlayerPedId()
            if IsPedShooting(ped) then
                local rot = GetGameplayCamRot(2)
                if prevRot then
                    local dx = math.abs(rot.x - prevRot.x)
                    local dz = math.abs(rot.z - prevRot.z)
                    local totalDelta = dx + dz
                    table.insert(shotWindow, totalDelta > threshold)
                    if #shotWindow > maxWindow then table.remove(shotWindow, 1) end

                    if #shotWindow >= maxWindow then
                        local snaps = 0
                        for _, v in ipairs(shotWindow) do if v then snaps = snaps + 1 end end
                        if snaps >= maxSnaps then
                            ONLY_AC_Client.Report("Aimbot Tespiti (Kamera Snap Analizi)", ("Son %s atışta %s snap tespit edildi"):format(maxWindow, snaps))
                            shotWindow = {}
                        end
                    end
                end
                prevRot = rot
            end
        end
    end)

    -- =====================================================================
    -- 7. SINIRSIZ STAMİNA TESPİTİ (Infinite Stamina)
    -- =====================================================================
    CreateThread(function()
        if not Config.Protections.AntiInfiniteStamina then return end
        local sprintStart = nil
        local maxSprint = Config.MaxConsecutiveSprintSeconds or 60

        while true do
            Wait(2000)
            local ped = PlayerPedId()
            if DoesEntityExist(ped) and not _IsEntityDead(ped) then
                if IsPedSprinting(ped) then
                    if not sprintStart then
                        sprintStart = GetGameTimer()
                    else
                        local elapsed = (GetGameTimer() - sprintStart) / 1000
                        local staminaLeft = GetPlayerSprintStaminaRemaining(PlayerId())
                        if elapsed > maxSprint and staminaLeft > 90.0 then
                            ONLY_AC_Client.Report("Sınırsız Stamina Hilesi (Infinite Stamina)", ("Sprint süresi: %.0f sn | Stamina: %.1f%%"):format(elapsed, staminaLeft))
                            sprintStart = nil
                        end
                    end
                else
                    sprintStart = nil
                end
            end
        end
    end)

    -- =====================================================================
    -- 8. PED BOYUT DEĞİŞTİRME TESPİTİ (Tiny/Giant Ped Hitbox Hilesi)
    -- =====================================================================
    CreateThread(function()
        if not Config.Protections.AntiTinyPed then return end
        while true do
            Wait(3000)
            local ped = PlayerPedId()
            if DoesEntityExist(ped) and not _IsEntityDead(ped) then
                local headPos = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
                local footPos = _GetEntityCoords(ped)
                local height = headPos.z - footPos.z
                if height < 0.5 or height > 2.5 then
                    ONLY_AC_Client.Report("Ped Boyut Değiştirme Hilesi (Tiny/Giant Ped)", ("Yükseklik: %.2f metre"):format(height))
                end
            end
        end
    end)
end)

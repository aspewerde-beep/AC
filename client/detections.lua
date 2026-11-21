-- =========================================================================
-- 465 AC v4.2.0 - DÜŞÜK RESMON İSTEMCİ KORUMA MOTORU (0.00-0.01ms HEDEFİ)
-- Birleştirilmiş Adaptif Döngüler, Çoklu Doğrulama & Sıfır False-Ban Koruması
-- =========================================================================

-- Kritik native referanslarını başlangıçta koru (Anti-Native Hook)
local _PlayerPedId = PlayerPedId
local _PlayerId = PlayerId
local _GetEntityCoords = GetEntityCoords
local _GetEntityHealth = GetEntityHealth
local _GetPedArmour = GetPedArmour
local _GetPlayerInvincible = GetPlayerInvincible
local _SetPlayerInvincible = SetPlayerInvincible
local _GetEntityCanBeDamaged = GetEntityCanBeDamaged
local _SetEntityCanBeDamaged = SetEntityCanBeDamaged
local _SetEntityVelocity = SetEntityVelocity
local _GetEntityVelocity = GetEntityVelocity
local _IsEntityDead = IsEntityDead
local _GetEntitySpeed = GetEntitySpeed
local _IsEntityVisible = IsEntityVisible
local _GetEntityAlpha = GetEntityAlpha
local _NetworkIsInSpectatorMode = NetworkIsInSpectatorMode

local strikes = {}
local function addStrike(key, limit)
    local threshold = limit or (Config and Config.ViolationStrikes) or 2
    strikes[key] = (strikes[key] or 0) + 1
    if strikes[key] >= threshold then
        strikes[key] = 0
        return true
    end
    return false
end

local function clearStrike(key)
    if strikes[key] and strikes[key] > 0 then
        strikes[key] = strikes[key] - 1
    end
end

-- Kamera açı farkını 360/-180 sarmalama hatası olmadan ölç
local function angleDelta(a, b)
    local d = (a - b + 180.0) % 360.0 - 180.0
    return math.abs(d)
end

-- Kamera rotasyonundan normalize 3D ileri yön vektörü hesapla
local function camForwardVector(rot)
    local rx = math.rad(rot.x)
    local rz = math.rad(rot.z)
    local cosX = math.abs(math.cos(rx))
    return vector3(-math.sin(rz) * cosX, math.cos(rz) * cosX, math.sin(rx))
end

CreateThread(function()
    while not AC465_Client.IsReady() do
        Wait(400)
    end

    AC465_Client.GrantSpawnGrace()

    AddEventHandler("playerSpawned", function()
        AC465_Client.GrantSpawnGrace()
    end)

    -- =====================================================================
    -- 1. ADAPTİF SAVAŞ, SİLAH, AİMBOT, SİLENT AİM & RPF KORUMASI
    -- Boşta 400ms (0.00ms resmon), elinde silah varken 80ms, ateş/nişan anında 5ms
    -- =====================================================================
    CreateThread(function()
        local lastShotTime = 0
        local prevRot = nil
        local shotWindow = {}
        local silentMissCount = 0
        local ignoredAmmoWeapons = {
            [`WEAPON_UNARMED`] = true,
            [`WEAPON_STUNGUN`] = true,
            [`WEAPON_FLAREGUN`] = true,
            [`WEAPON_PETROLCAN`] = true,
            [`WEAPON_FIREEXTINGUISHER`] = true,
            [`WEAPON_HAZARDCAN`] = true,
            [`WEAPON_FERTILIZERCAN`] = true
        }
        local rapidFireWhitelist = {
            [`WEAPON_MICROSMG`] = true,
            [`WEAPON_MINISMG`] = true,
            [`WEAPON_MACHINEPISTOL`] = true,
            [`WEAPON_APPISTOL`] = true,
            [`WEAPON_MINIGUN`] = true,
            [`WEAPON_RAYMINIGUN`] = true,
            [`WEAPON_MG`] = true,
            [`WEAPON_COMBATMG`] = true
        }

        while true do
            local ped = _PlayerPedId()
            local armed = DoesEntityExist(ped) and not _IsEntityDead(ped) and IsPedArmed(ped, 4)

            if not armed then
                prevRot = nil
                Wait(400)
            else
                local aimingOrFiring = IsControlPressed(0, 24) or IsControlPressed(0, 25) or IsPedShooting(ped)
                Wait(aimingOrFiring and 5 or 80)

                if IsPedShooting(ped) then
                    local now = GetGameTimer()
                    local _, currentWeapon = GetCurrentPedWeapon(ped, true)
                    local playerId = _PlayerId()

                    -- Rapid Fire kontrolü
                    if AC465_Shared.IsModuleEnabled("AntiRapidFire") and lastShotTime > 0 then
                        local diff = now - lastShotTime
                        if diff < 55 and not rapidFireWhitelist[currentWeapon] then
                            if addStrike("rapid_fire", 2) then
                                AC465_Client.Report("AntiRapidFire", "Seri Ateş Hilesi (Rapid Fire)", ("Ateş Aralığı: %s ms | Silah: %s"):format(diff, currentWeapon))
                            end
                        else
                            clearStrike("rapid_fire")
                        end
                    end

                    -- Sınırsız Şarjör / Mermi (Infinite Ammo / Clip)
                    if AC465_Shared.IsModuleEnabled("AntiInfiniteAmmo") and not ignoredAmmoWeapons[currentWeapon] then
                        local maxClip = GetMaxAmmoInClip(ped, currentWeapon, true)
                        local _, ammoInClip = GetAmmoInClip(ped, currentWeapon)
                        if maxClip > 0 and ammoInClip > (maxClip + 2) then
                            AC465_Client.Report("AntiInfiniteAmmo", "Sınırsız Şarjör / Mermi Hilesi (Infinite Ammo)", ("Şarjör: %s | Limit: %s"):format(ammoInClip, maxClip))
                        end
                    end

                    -- Hasar Çarpanı & RPF Manipülasyonu
                    if AC465_Shared.IsModuleEnabled("AntiDamageModifier") or AC465_Shared.IsModuleEnabled("AntiRPF") then
                        local wMod = GetPlayerWeaponDamageModifier(playerId)
                        local mMod = GetPlayerMeleeWeaponDamageModifier(playerId)
                        local wcMod = GetWeaponDamageModifier(currentWeapon)
                        if wMod > 1.08 or mMod > 1.08 or wcMod > 1.15 then
                            AC465_Client.Report("AntiDamageModifier", "Silah / RPF Hasar Çarpanı Hilesi", ("WeaponMod: %.2f | MeleeMod: %.2f | RPFMod: %.2f"):format(wMod, mMod, wcMod))
                        end
                    end

                    -- Aimbot Kamera Snap Analizi (360 Derece Wrap Korumalı)
                    local rot = GetGameplayCamRot(2)
                    if AC465_Shared.IsModuleEnabled("AntiAimbot") and prevRot then
                        local threshold = Config.AimbotAngleThreshold or 18.0
                        local maxWindow = Config.AimbotCheckWindow or 5
                        local maxSnaps = Config.AimbotSnapCount or 4
                        local delta = angleDelta(rot.x, prevRot.x) + angleDelta(rot.z, prevRot.z)
                        table.insert(shotWindow, delta > threshold)
                        if #shotWindow > maxWindow then table.remove(shotWindow, 1) end

                        if #shotWindow >= maxWindow then
                            local snaps = 0
                            for _, hit in ipairs(shotWindow) do
                                if hit then snaps = snaps + 1 end
                            end
                            if snaps >= maxSnaps then
                                AC465_Client.Report("AntiAimbot", "Aimbot Tespiti (Kamera Snap Analizi)", ("Son %s atışta %s ani sıçrama"):format(maxWindow, snaps))
                                shotWindow = {}
                            end
                        end
                    end
                    prevRot = rot

                    -- Silent Aim (Kamera Bakış Yönü vs Hedef Yönü Doğrulama)
                    if AC465_Shared.IsModuleEnabled("AntiSilentAim") then
                        local hasTarget, entity = GetEntityPlayerIsFreeAimingAt(playerId)
                        if not hasTarget or not DoesEntityExist(entity) then
                            local camPos = GetGameplayCamCoord()
                            local fwd = camForwardVector(rot)
                            local closestBad = false
                            for _, pid in ipairs(GetActivePlayers()) do
                                if pid ~= playerId then
                                    local tPed = GetPlayerPed(pid)
                                    if DoesEntityExist(tPed) and not _IsEntityDead(tPed) and HasPedBeenDamagedByWeapon(tPed, currentWeapon, 0) then
                                        local toTarget = _GetEntityCoords(tPed) - camPos
                                        local dist = #toTarget
                                        if dist > 6.0 and dist < 240.0 then
                                            local dir = toTarget / dist
                                            local dot = (fwd.x * dir.x) + (fwd.y * dir.y) + (fwd.z * dir.z)
                                            if dot < (Config.SilentAimMinDot or 0.45) then
                                                closestBad = true
                                                ClearEntityLastWeaponDamage(tPed)
                                                break
                                            end
                                        end
                                        ClearEntityLastWeaponDamage(tPed)
                                    end
                                end
                            end
                            if closestBad then
                                silentMissCount = silentMissCount + 1
                                if silentMissCount >= 2 then
                                    silentMissCount = 0
                                    AC465_Client.Report("AntiSilentAim", "Silent Aim Tespiti (Bakış Açısı Dışı Vuruş)", "Kamera bakış konisi dışında ardışık isabet")
                                end
                            elseif silentMissCount > 0 then
                                silentMissCount = silentMissCount - 1
                            end
                        end
                    end

                    lastShotTime = now
                end
            end
        end
    end)

    -- =====================================================================
    -- 2. HAREKET, NOCLIP, TELEPORT, ARAÇ, ZIRH & GODMODE KONTROLÜ (1000ms)
    -- =====================================================================
    CreateThread(function()
        local lastCoords = _GetEntityCoords(_PlayerPedId())
        local lastHealth = _GetEntityHealth(_PlayerPedId())

        while true do
            Wait(1000)
            local ped = _PlayerPedId()
            local playerId = _PlayerId()

            if DoesEntityExist(ped) and not _IsEntityDead(ped) then
                local currentCoords = _GetEntityCoords(ped)
                local distance = #(currentCoords - lastCoords)
                local inVehicle = IsPedInAnyVehicle(ped, false)
                local isGrace = AC465_Client.HasTeleportGrace()
                local inExcludeZone = AC465_Shared.IsInExcludeZone(currentCoords)
                local isAttachedToOther = IsEntityAttached(ped) or IsEntityAttachedToAnyPed(ped)

                -- 1) Teleport, Yaya Hız & Noclip (Grace / EMS Carry / ExcludeZone hariç + Çoklu Doğrulama)
                if not isGrace and not inExcludeZone and not isAttachedToOther and not IsPedFalling(ped) and not IsPedInParachuteFreeFall(ped) then
                    if AC465_Shared.IsModuleEnabled("AntiTeleport") then
                        if distance > (Config.MaxTeleportDistance or 90.0) and GetInteriorFromEntity(ped) == 0 then
                            if addStrike("teleport", 2) then
                                AC465_Client.Report("AntiTeleport", "Işınlanma (Teleport) Tespiti", ("Ardışık %.2f metre sıçrama"):format(distance))
                            end
                        else
                            clearStrike("teleport")
                        end
                    end

                    if not inVehicle and not IsPedRagdoll(ped) then
                        if AC465_Shared.IsModuleEnabled("AntiSpeedHack") then
                            if distance > (Config.MaxFootSpeed or 16.5) and _GetEntitySpeed(ped) > (Config.MaxFootSpeed or 16.5) then
                                if addStrike("foot_speed") then
                                    AC465_Client.Report("AntiSpeedHack", "Yaya Hız Hilesi (SpeedHack)", ("Hız: %.2f m/s"):format(_GetEntitySpeed(ped)))
                                end
                            else
                                clearStrike("foot_speed")
                            end
                        end

                        if AC465_Shared.IsModuleEnabled("AntiNoclip") then
                            local heightAboveGround = GetEntityHeightAboveGround(ped)
                            if heightAboveGround > 4.5 and distance > 14.5 and not IsPedClimbing(ped) and not IsPedDiving(ped) and not IsPedSwimming(ped) then
                                if addStrike("noclip") then
                                    AC465_Client.Report("AntiNoclip", "Uçma Hilesi (Noclip / Fly)", ("Yükseklik: %.2fm | Mesafe: %.2fm"):format(heightAboveGround, distance))
                                end
                            else
                                clearStrike("noclip")
                            end
                        end

                        if AC465_Shared.IsModuleEnabled("AntiGroundNoclip") then
                            local spd = _GetEntitySpeed(ped)
                            if spd > 19.5 and not IsPedJumpingOutOfVehicle(ped) and GetInteriorFromEntity(ped) == 0 then
                                if addStrike("ground_noclip") then
                                    AC465_Client.Report("AntiGroundNoclip", "Yerde Yürüyüş Noclip Bypass", ("Hız: %.2f m/s"):format(spd))
                                end
                            else
                                clearStrike("ground_noclip")
                            end
                        end
                    end
                end

                -- 2) Dikey Fırlatma (Anti-Launch Player)
                if not isGrace and not inVehicle and not isAttachedToOther and AC465_Shared.IsModuleEnabled("AntiLaunchPlayer") then
                    local vel = _GetEntityVelocity(ped)
                    if vel.z > (Config.MaxPlayerZVelocity or 34.0) then
                        _SetEntityVelocity(ped, 0.0, 0.0, 0.0)
                        AC465_Client.Report("AntiLaunchPlayer", "Karakter Fırlatma Hilesi (Anti-Launch)", ("Z İvmesi: %.2f m/s"):format(vel.z))
                    end
                end

                -- 3) Araç Kontrolleri (Hız, Car Fly, Modifiers, Godmode, Launch, Magneto)
                if inVehicle then
                    local veh = GetVehiclePedIsIn(ped, false)
                    if DoesEntityExist(veh) and GetPedInVehicleSeat(veh, -1) == ped then
                        local vehClass = GetVehicleClass(veh)
                        local isAircraft = (vehClass == 14 or vehClass == 15 or vehClass == 16)

                        if AC465_Shared.IsModuleEnabled("AntiSpeedHack") and not inExcludeZone and not isGrace then
                            local speedKMH = _GetEntitySpeed(veh) * 3.6
                            if speedKMH > (Config.MaxVehicleSpeedKMH or 360.0) then
                                if addStrike("veh_speed") then
                                    AC465_Client.Report("AntiSpeedHack", "Aşırı Araç Hızı (Vehicle SpeedHack)", ("Hız: %.1f km/s"):format(speedKMH))
                                end
                            else
                                clearStrike("veh_speed")
                            end
                        end

                        if AC465_Shared.IsModuleEnabled("AntiVehicleModifiers") then
                            local topMod = GetVehicleTopSpeedModifier(veh)
                            if topMod and topMod > (Config.MaxVehicleSpeedModifier or 1.65) then
                                SetVehicleCheatPowerIncrease(veh, 1.0)
                                AC465_Client.Report("AntiVehicleModifiers", "Araç Güç / Hız Çarpanı Hilesi", ("Çarpan: %.2f"):format(topMod))
                            end
                        end

                        if AC465_Shared.IsModuleEnabled("AntiVehicleFly") and not isAircraft and not inExcludeZone and not isGrace then
                            local hAbove = GetEntityHeightAboveGround(veh)
                            local spd = _GetEntitySpeed(veh)
                            if hAbove > 25.0 and spd > 22.0 and IsEntityInAir(veh) then
                                if addStrike("car_fly", 2) then
                                    AC465_Client.Report("AntiVehicleFly", "Araç Uçurma Hilesi (Car Fly)", ("Yükseklik: %.1fm | Hız: %.1f m/s"):format(hAbove, spd))
                                end
                            else
                                clearStrike("car_fly")
                            end
                        end

                        if AC465_Shared.IsModuleEnabled("AntiLaunchVehicle") and not isAircraft and not isGrace then
                            local vVel = _GetEntityVelocity(veh)
                            if vVel.z > (Config.MaxVehicleZVelocity or 40.0) then
                                _SetEntityVelocity(veh, 0.0, 0.0, 0.0)
                                AC465_Client.Report("AntiLaunchVehicle", "Araç Fırlatma Hilesi (Anti-Launch Vehicle)", ("Z İvmesi: %.2f m/s"):format(vVel.z))
                            end
                        end

                        if AC465_Shared.IsModuleEnabled("AntiVehicleGodmode") then
                            if not _GetEntityCanBeDamaged(veh) then
                                _SetEntityCanBeDamaged(veh, true)
                                AC465_Client.Report("AntiVehicleGodmode", "Araç Ölümsüzlüğü (Vehicle Godmode)", "Hasar almama aktif")
                            end
                        end
                    end
                end

                -- 4) Ölümsüzlük, Zırh ve Hızlı Can Doldurma
                local curHealth = _GetEntityHealth(ped)
                local curArmor = _GetPedArmour(ped)

                if AC465_Shared.IsModuleEnabled("AntiGodmode") then
                    if _GetPlayerInvincible(playerId) then
                        _SetPlayerInvincible(playerId, false)
                        AC465_Client.Report("AntiGodmode", "Ölümsüzlük Hilesi (Native Godmode)", "GetPlayerInvincible aktif")
                    end
                    if not _GetEntityCanBeDamaged(ped) and not isGrace and not inExcludeZone then
                        _SetEntityCanBeDamaged(ped, true)
                        AC465_Client.Report("AntiGodmode", "Hasar Almama Hilesi (Demi-God)", "CanBeDamaged kapalı")
                    end
                    if curHealth > (Config.MaxHealth or 200) then
                        SetEntityHealth(ped, Config.MaxHealth or 200)
                        AC465_Client.Report("AntiGodmode", "Maksimum Üstü Can Hilesi", ("Can: %s"):format(curHealth))
                    end
                end

                if AC465_Shared.IsModuleEnabled("AntiArmorHack") and curArmor > (Config.MaxArmor or 100) then
                    SetPedArmour(ped, Config.MaxArmor or 100)
                    AC465_Client.Report("AntiArmorHack", "Maksimum Üstü Zırh Hilesi (Armor Modifier)", ("Zırh: %s"):format(curArmor))
                end

                if AC465_Shared.IsModuleEnabled("AntiLegitGodmode") and not isGrace and not inExcludeZone then
                    if lastHealth < 125 and curHealth >= 195 then
                        AC465_Client.Report("AntiLegitGodmode", "Anlık Can Yenileme (Fast Regen / Legit Godmode)", ("Eski: %s -> Yeni: %s"):format(lastHealth, curHealth))
                    end
                end

                lastCoords = currentCoords
                lastHealth = curHealth
            else
                lastCoords = DoesEntityExist(ped) and _GetEntityCoords(ped) or lastCoords
                lastHealth = DoesEntityExist(ped) and _GetEntityHealth(ped) or lastHealth
            end
        end
    end)

    -- =====================================================================
    -- 3. DÜŞÜK FREKANSLI BÜTÜNLÜK, GÖRÜŞ, ENJEKSİYON & OBJE KORUMASI (2.5sn)
    -- =====================================================================
    CreateThread(function()
        local sprintStart = nil
        local checkNatives = {
            { fn = function() return GetEntityCoords end, name = "GetEntityCoords" },
            { fn = function() return GetEntityHealth end, name = "GetEntityHealth" },
            { fn = function() return SetPlayerInvincible end, name = "SetPlayerInvincible" },
            { fn = function() return GetPlayerInvincible end, name = "GetPlayerInvincible" },
            { fn = function() return GetPedArmour end, name = "GetPedArmour" },
            { fn = function() return SetEntityVisible end, name = "SetEntityVisible" },
            { fn = function() return NetworkIsInSpectatorMode end, name = "NetworkIsInSpectatorMode" }
        }
        local suspiciousGlobals = {
            "RedEngine", "eulen", "Susano", "Lumia", "Nexus", "Macho",
            "LynxMenu", "TiagoModz", "HamHaxia", "Fendr", "Dopamine"
        }

        while true do
            Wait(2500)
            local ped = _PlayerPedId()
            local playerId = _PlayerId()
            local isGrace = AC465_Client.HasTeleportGrace()

            -- Anti-Native Hook
            if AC465_Shared.IsModuleEnabled("AntiNativeHook") then
                for _, item in ipairs(checkNatives) do
                    local info = debug.getinfo(item.fn())
                    if info and (info.what ~= "C" or (info.source and info.source ~= "=[C]")) then
                        AC465_Client.Report("AntiNativeHook", "İstemci Fonksiyon Bütünlük İhlali (Native Hook)", ("Hedef: %s (%s)"):format(item.name, tostring(info.what)))
                        break
                    end
                end
                if DoesEntityExist(ped) then
                    local c1 = _GetEntityCoords(ped)
                    local c2 = GetEntityCoords(ped)
                    if #(c1 - c2) > 2.5 then
                        AC465_Client.Report("AntiNativeHook", "Koordinat Fonksiyon Manipülasyonu", ("Fark: %.1fm"):format(#(c1 - c2)))
                    end
                end
            end

            -- Global Executor / Menu Değişken Denetimi
            if AC465_Shared.IsModuleEnabled("AntiNUIDevTools") or AC465_Shared.IsModuleEnabled("AntiMenuDetection") then
                for _, gVar in ipairs(suspiciousGlobals) do
                    if _G[gVar] ~= nil then
                        AC465_Client.Report("AntiMenuDetection", "Hile Menüsü / Executor Değişkeni Tespiti", ("Modül: %s"):format(gVar))
                        break
                    end
                end
            end

            if DoesEntityExist(ped) and not _IsEntityDead(ped) then
                -- Yasaklı Ağır Silahlar
                if AC465_Shared.IsModuleEnabled("AntiBlacklistedWeapons") and Config.BlacklistedWeapons then
                    for wHash, _ in pairs(Config.BlacklistedWeapons) do
                        if HasPedGotWeapon(ped, wHash, false) then
                            RemoveAllPedWeapons(ped, true)
                            AC465_Client.Report("AntiBlacklistedWeapons", "Yasaklı Ağır Silah Tespiti", ("Silah Hash: %s"):format(wHash))
                            break
                        end
                    end
                end

                -- Görünmezlik (Invisibility / Alpha)
                if AC465_Shared.IsModuleEnabled("AntiInvisibility") and not isGrace then
                    local vis = _IsEntityVisible(ped)
                    local alpha = _GetEntityAlpha(ped)
                    if not vis or alpha < 50 then
                        SetEntityVisible(ped, true, false)
                        ResetEntityAlpha(ped)
                        AC465_Client.Report("AntiInvisibility", "Görünmezlik Hilesi (Ghostmode)", ("Visible: %s | Alpha: %s"):format(tostring(vis), alpha))
                    end
                end

                -- Süper Zıplama & No-Collision
                if AC465_Shared.IsModuleEnabled("AntiSuperJump") and IsPedDoingSuperJump(playerId) then
                    AC465_Client.Report("AntiSuperJump", "Süper Zıplama Hilesi (Super Jump)", "IsPedDoingSuperJump aktif")
                end
                if AC465_Shared.IsModuleEnabled("AntiNoCollision") and GetEntityCollisionDisabled(ped) and not isGrace then
                    SetEntityCollision(ped, true, true)
                    AC465_Client.Report("AntiNoCollision", "Duvar Geçişi Hilesi (No-Collision)", "Çarpışma devre dışı")
                end

                -- Termal & Gece Görüşü
                if AC465_Shared.IsModuleEnabled("AntiNightThermalVision") then
                    if GetUsingnightvision() then
                        SetNightvision(false)
                        AC465_Client.Report("AntiNightThermalVision", "Gece Görüşü Hilesi (Night Vision)", "Yetkisiz vizyon")
                    end
                    if GetUsingseethrough() then
                        SetSeethrough(false)
                        AC465_Client.Report("AntiNightThermalVision", "Termal Görüş Hilesi (Thermal Vision)", "Yetkisiz vizyon")
                    end
                end

                -- Freecam / Spectate
                if AC465_Shared.IsModuleEnabled("AntiSpectate") and not isGrace and _NetworkIsInSpectatorMode() then
                    AC465_Client.Report("AntiSpectate", "Yetkisiz İzleyici / Freecam Modu", "Spectator Mode aktif")
                end

                -- Anti-Taser / No-Ragdoll
                if AC465_Shared.IsModuleEnabled("AntiRagdoll") and IsPedBeingStunned(ped, 0) and not IsPedRagdoll(ped) then
                    AC465_Client.Report("AntiRagdoll", "Taser / Ragdoll Engelleme Hilesi", "No-Ragdoll aktif")
                end

                -- Tiny / Giant Ped Hitbox Hilesi
                if AC465_Shared.IsModuleEnabled("AntiTinyPed") then
                    local headPos = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
                    local footPos = _GetEntityCoords(ped)
                    local height = headPos.z - footPos.z
                    if height < 0.45 or height > 2.55 then
                        AC465_Client.Report("AntiTinyPed", "Ped Boyut Değiştirme Hilesi (Hitbox)", ("Boy: %.2fm"):format(height))
                    end
                end

                -- Yetkisiz Ped Modeli (Grace sonrası + WhitelistedPeds ile)
                if AC465_Shared.IsModuleEnabled("AntiPedChange") and not isGrace and Config.WhitelistedPeds then
                    local model = GetEntityModel(ped)
                    if not Config.WhitelistedPeds[model] then
                        AC465_Client.Report("AntiPedChange", "Yetkisiz Karakter Modeli (Ped Change)", ("Model Hash: %s"):format(model))
                    end
                end

                -- Sınırsız Stamina
                if AC465_Shared.IsModuleEnabled("AntiInfiniteStamina") then
                    if IsPedSprinting(ped) then
                        if not sprintStart then
                            sprintStart = GetGameTimer()
                        elseif ((GetGameTimer() - sprintStart) / 1000.0) > (Config.MaxConsecutiveSprintSeconds or 60) then
                            local rem = GetPlayerSprintStaminaRemaining(playerId)
                            if rem > 90.0 then
                                AC465_Client.Report("AntiInfiniteStamina", "Sınırsız Stamina Hilesi", ("Stamina: %.1f%%"):format(rem))
                                sprintStart = nil
                            end
                        end
                    else
                        sprintStart = nil
                    end
                end

                -- Akıllı Anti-Attach (Yalnızca oyuncuya yapışan izinsiz CObject trol prop'larını temizle; EMS kucağa almayı bozmaz!)
                if AC465_Shared.IsModuleEnabled("AntiAttach") then
                    local pool = GetGamePool and GetGamePool("CObject")
                    if pool then
                        for _, obj in ipairs(pool) do
                            if DoesEntityExist(obj) and GetEntityAttachedTo(obj) == ped then
                                local model = GetEntityModel(obj)
                                if not Config.ObjectWhitelist or not Config.ObjectWhitelist[model] then
                                    DetachEntity(obj, true, true)
                                    SetEntityAsMissionEntity(obj, false, true)
                                    DeleteEntity(obj)
                                end
                            end
                        end
                    end
                end
            else
                sprintStart = nil
            end
        end
    end)
end)

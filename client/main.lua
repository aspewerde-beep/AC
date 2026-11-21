-- =========================================================================
-- 465 AC v4.2.0 - İSTEMCİ ANA MODÜL & GÜVENLİK ÇEKİRDEĞİ
-- Kapsüllenmiş Oturum Anahtarı, Anti-Replay Nonce, Adaptif Heartbeat & Muafiyet
-- =========================================================================

local sessionToken = nil
local isInitialized = false
local reportNonce = 0
local lastReportTimes = {}
local teleportGraceUntil = 0

-- Harici scriptler (garaj, ev, admin tp) için geçici ışınlanma muafiyeti
exports("AllowTeleport", function(durationMs)
    local ms = tonumber(durationMs) or 5000
    local target = GetGameTimer() + math.min(math.max(ms, 500), 30000)
    if target > teleportGraceUntil then
        teleportGraceUntil = target
    end
end)

-- Sunucu tarafından tetiklenen geçici ışınlanma muafiyeti
RegisterNetEvent("ac465:client:allowTeleport", function(durationMs)
    local ms = tonumber(durationMs) or 5000
    local target = GetGameTimer() + math.min(math.max(ms, 500), 30000)
    if target > teleportGraceUntil then
        teleportGraceUntil = target
    end
end)

-- İç istemci modülleri arası güvenli köprü (Token dışarıya açılmaz)
AC465_Client = {}

function AC465_Client.Report(moduleName, reason, details)
    if not sessionToken then return end
    if moduleName and AC465_Shared and not AC465_Shared.IsModuleEnabled(moduleName) then
        return
    end

    -- Spam / çoklu rapor koruması (aynı modülden 3.5 sn içinde tek bildirim)
    local now = GetGameTimer()
    local key = tostring(moduleName or reason)
    if lastReportTimes[key] and (now - lastReportTimes[key]) < 3500 then
        return
    end
    lastReportTimes[key] = now

    reportNonce = reportNonce + 1
    TriggerServerEvent("ac465:server:reportDetection", sessionToken, reason, details, reportNonce, moduleName)
end

function AC465_Client.HasTeleportGrace()
    return GetGameTimer() < teleportGraceUntil
end

function AC465_Client.GrantSpawnGrace()
    local sec = (Config and Config.SpawningGracePeriodSeconds) or 18
    local target = GetGameTimer() + (sec * 1000)
    if target > teleportGraceUntil then
        teleportGraceUntil = target
    end
end

function AC465_Client.IsReady()
    return isInitialized
end

-- Handshake yanıtı: token ve sanitize edilmiş yapılandırmayı al
RegisterNetEvent("ac465:client:handshakeResponse", function(token, syncedConfig)
    sessionToken = token
    if type(syncedConfig) == "table" then
        for k, v in pairs(syncedConfig) do
            Config[k] = v
        end
    end
    isInitialized = true
end)

-- Canlı yapılandırma senkronizasyonu (Web Paneli veya /465ac_protect sonrası)
RegisterNetEvent("ac465:client:syncProtections", function(protections)
    if type(protections) == "table" then
        Config.Protections = protections
    end
end)

-- Sunucudan temizlik tetiklendiğinde yerel bilgi
CreateThread(function()
    while not isInitialized do
        TriggerServerEvent("ac465:client:requestHandshake")
        Wait(2500)
    end

    while true do
        Wait((Config and Config.HeartbeatInterval) or 10000)
        if sessionToken then
            local ped = PlayerPedId()
            local coords = DoesEntityExist(ped) and GetEntityCoords(ped) or vector3(0.0, 0.0, 0.0)
            local health = DoesEntityExist(ped) and GetEntityHealth(ped) or 0
            local armor = DoesEntityExist(ped) and GetPedArmour(ped) or 0
            local model = DoesEntityExist(ped) and GetEntityModel(ped) or 0
            local inVeh = DoesEntityExist(ped) and IsPedInAnyVehicle(ped, false) or false

            TriggerServerEvent("ac465:client:heartbeat", sessionToken, {
                coords = { x = coords.x, y = coords.y, z = coords.z },
                health = health,
                armor = armor,
                model = model,
                inVehicle = inVeh
            })
        end
    end
end)

-- Anti-Resource Stop (Script durdurulursa bildir)
AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if AC465_Shared.IsModuleEnabled("AntiResourceStop") and sessionToken then
            TriggerServerEvent("ac465:server:resourceStopped", sessionToken)
        end
    end
end)

-- Yetkisiz Resource Başlatma / Enjeksiyon Tespiti
AddEventHandler("onClientResourceStart", function(resourceName)
    if isInitialized and resourceName ~= GetCurrentResourceName() then
        if AC465_Shared.IsModuleEnabled("AntiResourceInjection") and sessionToken then
            TriggerServerEvent("ac465:server:suspiciousResourceStart", sessionToken, resourceName)
        end
    end
end)

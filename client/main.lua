-- =========================================================================
-- ONLY AC v3.0.0 (ULTIMATE EDITION) - İSTEMCİ ANA MODÜL & GÜVENLİK
-- Gelişmiş Nonce Koruması, Geliştirilmiş Heartbeat, Enjeksiyon & Ped Denetimi
-- =========================================================================

ONLY_AC_Client = {}
local sessionToken = nil
local activeProtections = {}
local isInitialized = false
local reportNonce = 0

-- Sunucuya doğrulanmış tespit bildirimi gönder (Nonce ile korumalı)
function ONLY_AC_Client.Report(reason, details)
    if not sessionToken then return end
    reportNonce = reportNonce + 1
    TriggerServerEvent("onlyac:server:reportDetection", sessionToken, reason, details, reportNonce)
end

-- Handshake yanıtı (Sunucudan token ve aktif korumaları al)
RegisterNetEvent("onlyac:client:handshakeResponse", function(token, protections)
    sessionToken = token
    activeProtections = protections or {}
    isInitialized = true
end)

-- Başlangıçta sunucudan token ve yapılandırma talep et
CreateThread(function()
    while not isInitialized do
        TriggerServerEvent("onlyac:client:requestHandshake")
        Wait(3000)
    end

    -- Geliştirilmiş Heartbeat Döngüsü: Sunucuya periyodik koordinat, can ve model bilgisi iletir
    while true do
        Wait(Config.HeartbeatInterval or 10000)
        if sessionToken then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local health = GetEntityHealth(ped)
            local model = GetEntityModel(ped)

            TriggerServerEvent("onlyac:client:heartbeat", sessionToken, {
                coords = { x = coords.x, y = coords.y, z = coords.z },
                health = health,
                model = model
            })
        end
    end
end)

-- Anti-Resource Stop (Hile menüsü veya executor ile script durdurulursa sunucuya derhal bildir)
AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if sessionToken then
            TriggerServerEvent("onlyac:server:resourceStopped", sessionToken)
        end
        ONLY_AC_Client.Report("Anti-Cheat Kaynağı Durduruldu (Resource Stop)", ("Kaynak: %s"):format(resourceName))
    end
end)

-- Yetkisiz Resource Başlatma / Enjeksiyon Tespiti (Resource Injection)
AddEventHandler("onClientResourceStart", function(resourceName)
    -- Oyuncu oyuna girdikten sonra habersizce başlatılan harici resource'ları yakala
    if isInitialized and resourceName ~= GetCurrentResourceName() then
        if Config and Config.Protections and Config.Protections.AntiResourceInjection then
            TriggerServerEvent("onlyac:server:suspiciousResourceStart", sessionToken, resourceName)
        end
    end
end)

-- Yetkisiz Ped / Karakter Değişimi Denetimi (AntiPedChange)
CreateThread(function()
    while not isInitialized do
        Wait(1000)
    end

    local allowedPeds = {
        [`mp_m_freemode_01`] = true,
        [`mp_f_freemode_01`] = true
    }

    while true do
        Wait(3000)
        if Config and Config.Protections and Config.Protections.AntiPedChange then
            local ped = PlayerPedId()
            if DoesEntityExist(ped) and not IsEntityDead(ped) then
                local currentModel = GetEntityModel(ped)
                if not allowedPeds[currentModel] then
                    ONLY_AC_Client.Report("Yetkisiz Karakter Modeli (Anti-PedChange)", ("İzinsiz Model Hash: %s"):format(currentModel))
                end
            end
        end
    end
end)

-- Fonksiyon ve değişken dışa aktarımı
function ONLY_AC_Client.IsReady()
    return isInitialized
end

function ONLY_AC_Client.GetProtections()
    return activeProtections
end

function ONLY_AC_Client.GetSessionToken()
    return sessionToken
end

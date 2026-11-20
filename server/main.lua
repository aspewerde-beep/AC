-- =========================================================================
-- ONLY AC v3.0.0 (ULTIMATE EDITION) - SUNUCU ANA MODÜL & GÜVENLİK
-- Nonce Doğrulama, Gelişmiş Heartbeat & Cross-Check, İstatistikler & Yetkili Komutları
-- =========================================================================

ONLY_AC = {}
ONLY_AC.RecentLogs = {}
ONLY_AC.Stats = {
    totalDetections = 0,
    totalBans = 0,
    totalKicks = 0,
    startTime = os.time()
}
local clientTokens = {}
local clientNonces = {}
local playerLastHeartbeat = {}

-- Yetkili / Bypass kontrolü (FiveM ACE izinleri)
function ONLY_AC.IsBypass(src)
    if src == 0 then return true end
    if not Config.AcePermission or Config.AcePermission == "" then return false end
    return IsPlayerAceAllowed(src, Config.AcePermission)
end

-- Son Heartbeat bilgisini al
function ONLY_AC.GetLastHeartbeat(src)
    return playerLastHeartbeat[src]
end

-- Discord Webhook Bildirimi Gönder
function ONLY_AC.SendDiscordLog(src, reason, details, action, screenshotUrl)
    if not Config.DiscordWebhook or Config.DiscordWebhook == "" or Config.DiscordWebhook:sub(1, 4) ~= "http" then
        return
    end

    local playerName = GetPlayerName(src) or "Bilinmeyen"
    local ids = BanSystem.GetIdentifiers(src)
    local ping = GetPlayerPing(src) or 0

    local fields = {
        { name = "Oyuncu Adı", value = ("`%s` (ID: %s)"):format(playerName, src), inline = true },
        { name = "Uygulanan Eylem", value = ("`%s`"):format(action:upper()), inline = true },
        { name = "Ping", value = ("`%s ms`"):format(ping), inline = true },
        { name = "Tespit Nedeni", value = ("**%s**"):format(reason), inline = false },
        { name = "Ekstra Detay", value = ("```%s```"):format(details or "Detay yok"), inline = false },
        { name = "Discord", value = ids.discord ~= "N/A" and ("<@%s>"):format(ids.discord:gsub("discord:", "")) or "`N/A`", inline = true },
        { name = "FiveM License", value = ("`%s`"):format(ids.license), inline = true },
        { name = "Steam ID", value = ("`%s`"):format(ids.steam), inline = true }
    }

    local embed = {
        {
            color = Config.EmbedColor or 16711680,
            title = "🛡️ " .. (Config.ServerName or "ONLY AC") .. " - Hile Tespiti",
            description = "Bir oyuncuda hile/anormallik tespit edildi ve işlem yapıldı.",
            fields = fields,
            footer = { text = "ONLY AC v3.0.0 | " .. os.date("%Y-%m-%d %H:%M:%S") }
        }
    }

    if screenshotUrl and screenshotUrl ~= "" then
        embed[1].image = { url = screenshotUrl }
    end

    local payload = json.encode({
        username = Config.ServerName or "ONLY AC",
        embeds = embed
    })

    PerformHttpRequest(Config.DiscordWebhook, function(err, text, headers) end, "POST", payload, { ["Content-Type"] = "application/json" })
end

-- Ekran Görüntüsü Alma & Ceza Yürütme
function ONLY_AC.Detect(src, reason, details, customAction)
    if ONLY_AC.IsBypass(src) then
        return
    end

    local action = customAction or Config.DefaultAction or "ban"
    local playerName = GetPlayerName(src) or "Bilinmeyen"

    print(("^1[ONLY AC TESPİT]^0 [%s] %s (ID: %s) -> Sebep: %s | Detay: %s"):format(
        action:upper(),
        playerName,
        src,
        reason,
        details or "Yok"
    ))

    -- İstatistikleri Güncelle
    ONLY_AC.Stats.totalDetections = ONLY_AC.Stats.totalDetections + 1

    -- Canlı Web Logu Ekle (Son 50 kayıt)
    table.insert(ONLY_AC.RecentLogs, 1, {
        time = os.date("%H:%M:%S"),
        player = playerName .. " (ID " .. src .. ")",
        reason = reason,
        details = details or "Yok",
        action = action
    })
    if #ONLY_AC.RecentLogs > 50 then
        table.remove(ONLY_AC.RecentLogs, #ONLY_AC.RecentLogs)
    end

    -- screenshot-basic entegrasyonu varsa ekran görüntüsü al
    if Config.ScreenCaptureEnabled and GetResourceState("screenshot-basic") == "started" then
        pcall(function()
            exports['screenshot-basic']:requestClientScreenshot(src, {}, function(err, data)
                ONLY_AC.SendDiscordLog(src, reason, details, action, nil)
            end)
        end)
    else
        ONLY_AC.SendDiscordLog(src, reason, details, action, nil)
    end

    -- Eylemi uygula
    if action == "ban" then
        ONLY_AC.Stats.totalBans = ONLY_AC.Stats.totalBans + 1
        BanSystem.AddBan(src, reason)
    elseif action == "kick" then
        ONLY_AC.Stats.totalKicks = ONLY_AC.Stats.totalKicks + 1
        DropPlayer(src, ("\n[ONLY AC] Sunucudan Atıldınız!\nSebep: %s"):format(reason))
    end
end

-- İstemci için benzersiz oturum belirteci (token) oluştur
local function generateToken(src)
    local token = ("OAC-%s-%s-%s"):format(src, os.time(), math.random(100000, 999999))
    clientTokens[src] = token
    return token
end

-- Oyuncu bağlandığında token gönder ve oturumu başlat
RegisterNetEvent("onlyac:client:requestHandshake", function()
    local src = source
    local token = generateToken(src)
    clientNonces[src] = 0
    playerLastHeartbeat[src] = os.time()
    TriggerClientEvent("onlyac:client:handshakeResponse", src, token, Config.Protections)
end)

-- Geliştirilmiş Heartbeat Dinleyici (Periyodik can, konum cross-check)
RegisterNetEvent("onlyac:client:heartbeat", function(token, data)
    local src = source
    if not clientTokens[src] or clientTokens[src] ~= token then return end
    playerLastHeartbeat[src] = os.time()

    -- Cross-check verisi kontrolü (Koordinat manipülasyonu / Spoofing)
    if data and type(data) == "table" and data.coords and not ONLY_AC.IsBypass(src) then
        local ped = GetPlayerPed(src)
        if DoesEntityExist(ped) then
            local srvCoords = GetEntityCoords(ped)
            local cliCoords = vector3(data.coords.x or 0, data.coords.y or 0, data.coords.z or 0)
            local diff = #(srvCoords - cliCoords)
            -- Eğer istemcinin iddia ettiği konum ile sunucu konumu arasında devasa fark varsa
            if diff > 150.0 then
                ONLY_AC.Detect(src, "Koordinat Sahteciliği (Coords Desync / Spoofing)", ("Fark: %.1f metre"):format(diff), "kick")
            end
        end
    end
end)

-- İstemciden gelen doğrulanmış tespit bildirimi (Nonce Doğrulamalı)
RegisterNetEvent("onlyac:server:reportDetection", function(token, reason, details, nonce)
    local src = source
    -- Token doğrulaması yap
    if not clientTokens[src] or clientTokens[src] ~= token then
        ONLY_AC.Detect(src, "Geçersiz Güvenlik Belirteci (Token Sahteciliği)", "Token mismatch", "ban")
        return
    end

    -- Nonce Doğrulaması (Replay saldırılarını ve sahte rapor injectlerini önle)
    if nonce then
        local lastNonce = clientNonces[src] or 0
        if type(nonce) ~= "number" or nonce <= lastNonce then
            ONLY_AC.Detect(src, "Geçersiz Rapor Sıralaması (Nonce Replay / Sahtecilik)", ("Alınan Nonce: %s | Son: %s"):format(tostring(nonce), tostring(lastNonce)), "ban")
            return
        end
        clientNonces[src] = nonce
    end

    ONLY_AC.Detect(src, reason, details)
end)

-- Anti-Cheat Kaynağı Durdurulduğunda (Client Resource Stop)
RegisterNetEvent("onlyac:server:resourceStopped", function(token)
    local src = source
    if clientTokens[src] and clientTokens[src] == token then
        if not ONLY_AC.IsBypass(src) then
            ONLY_AC.Detect(src, "Anti-Cheat Kaynağı Durduruldu (Resource Stop)", "İstemci AC resource'unun durdurulduğunu bildirdi", "kick")
        end
    end
end)

-- Şüpheli / Yetkisiz Resource Başlatma Tespiti (Resource Injection)
RegisterNetEvent("onlyac:server:suspiciousResourceStart", function(token, resourceName)
    local src = source
    if clientTokens[src] and clientTokens[src] == token then
        if not ONLY_AC.IsBypass(src) and Config.Protections and Config.Protections.AntiResourceInjection then
            ONLY_AC.Detect(src, "Yetkisiz Resource Enjeksiyonu (Resource Injection)", ("Şüpheli Kaynak: %s"):format(resourceName or "Bilinmeyen"), "kick")
        end
    end
end)

-- Oyuncu ayrıldığında oturumunu temizle
AddEventHandler("playerDropped", function()
    local src = source
    clientTokens[src] = nil
    clientNonces[src] = nil
    playerLastHeartbeat[src] = nil
end)

-- Bal Küpü (Honeypot) Eventlerini Kaydet
if Config.Protections.AntiHoneypotEvents and Config.HoneypotEvents then
    for _, eventName in ipairs(Config.HoneypotEvents) do
        RegisterNetEvent(eventName, function(...)
            local src = source
            ONLY_AC.Detect(src, "Bal Küpü (Honeypot Event) Tetiklendi", ("Tetiklenen Event: %s"):format(eventName), "ban")
        end)
    end
end

-- =========================================================================
-- YETKİLİ KOMUTLARI
-- =========================================================================

-- /onlyac_check <id>
RegisterCommand("onlyac_check", function(src, args)
    if src ~= 0 and not ONLY_AC.IsBypass(src) then
        TriggerClientEvent("chat:addMessage", src, { color = {255, 0, 0}, args = {"ONLY AC", "Bu komutu kullanma yetkiniz yok!"} })
        return
    end

    local target = tonumber(args[1])
    if not target or not GetPlayerName(target) then
        local msg = "Kullanım: /onlyac_check <oyuncu_id>"
        if src == 0 then print(msg) else TriggerClientEvent("chat:addMessage", src, { color = {255, 255, 0}, args = {"ONLY AC", msg} }) end
        return
    end

    local ped = GetPlayerPed(target)
    local coords = GetEntityCoords(ped)
    local health = GetEntityHealth(ped)
    local armor = GetPedArmour(ped)
    local ping = GetPlayerPing(target)
    local ids = BanSystem.GetIdentifiers(target)
    local info = ("\n[OYUNCU BİLGİSİ - ID %s]\nİsim: %s\nPing: %sms\nCan: %s | Zırh: %s\nKoordinat: %.1f, %.1f, %.1f\nDiscord: %s\nLicense: %s\nSteam: %s"):format(
        target, GetPlayerName(target), ping, health, armor, coords.x, coords.y, coords.z, ids.discord, ids.license, ids.steam
    )

    if src == 0 then
        print(info)
    else
        TriggerClientEvent("chat:addMessage", src, { color = {0, 255, 128}, args = {"ONLY AC", info} })
    end
end, false)

-- /onlyac_stats: Detaylı çalışma süresi ve tespit istatistikleri
RegisterCommand("onlyac_stats", function(src, args)
    if src ~= 0 and not ONLY_AC.IsBypass(src) then
        TriggerClientEvent("chat:addMessage", src, { color = {255, 0, 0}, args = {"ONLY AC", "Bu komutu kullanma yetkiniz yok!"} })
        return
    end

    local uptimeSec = os.time() - (ONLY_AC.Stats.startTime or os.time())
    local hours = math.floor(uptimeSec / 3600)
    local minutes = math.floor((uptimeSec % 3600) / 60)
    local seconds = uptimeSec % 60
    local uptimeStr = ("%sh %sd %ss"):format(hours, minutes, seconds)

    local info = ("\n[ONLY AC v3.0.0 İSTATİSTİKLERİ]\nÇalışma Süresi: %s\nToplam Tespit: %s\nToplam Ban: %s\nToplam Kick: %s\nAktif Oyuncu Sayısı: %s"):format(
        uptimeStr,
        ONLY_AC.Stats.totalDetections,
        ONLY_AC.Stats.totalBans,
        ONLY_AC.Stats.totalKicks,
        #GetPlayers()
    )

    if src == 0 then
        print(info)
    else
        TriggerClientEvent("chat:addMessage", src, { color = {0, 200, 255}, args = {"ONLY AC", info} })
    end
end, false)

-- /onlyac_kick <id> <sebep>: Manuel oyuncu atma
RegisterCommand("onlyac_kick", function(src, args)
    if src ~= 0 and not ONLY_AC.IsBypass(src) then
        TriggerClientEvent("chat:addMessage", src, { color = {255, 0, 0}, args = {"ONLY AC", "Bu komutu kullanma yetkiniz yok!"} })
        return
    end

    local target = tonumber(args[1])
    if not target or not GetPlayerName(target) then
        local msg = "Kullanım: /onlyac_kick <oyuncu_id> <sebep>"
        if src == 0 then print(msg) else TriggerClientEvent("chat:addMessage", src, { color = {255, 255, 0}, args = {"ONLY AC", msg} }) end
        return
    end

    table.remove(args, 1)
    local reason = table.concat(args, " ")
    if reason == "" then reason = "Yetkili tarafından atıldınız" end

    ONLY_AC.Detect(target, "Yetkili Komutu ile Atıldı (Kick)", reason, "kick")
end, false)

-- /onlyac_ban <id> <sebep>: Manuel oyuncu yasaklama
RegisterCommand("onlyac_ban", function(src, args)
    if src ~= 0 and not ONLY_AC.IsBypass(src) then
        TriggerClientEvent("chat:addMessage", src, { color = {255, 0, 0}, args = {"ONLY AC", "Bu komutu kullanma yetkiniz yok!"} })
        return
    end

    local target = tonumber(args[1])
    if not target or not GetPlayerName(target) then
        local msg = "Kullanım: /onlyac_ban <oyuncu_id> <sebep>"
        if src == 0 then print(msg) else TriggerClientEvent("chat:addMessage", src, { color = {255, 255, 0}, args = {"ONLY AC", msg} }) end
        return
    end

    table.remove(args, 1)
    local reason = table.concat(args, " ")
    if reason == "" then reason = "Yetkili tarafından yasaklandınız" end

    ONLY_AC.Detect(target, "Yetkili Komutu ile Yasaklandı (Ban)", reason, "ban")
end, false)

-- /onlyac_protect <ModülAdı> <on/off>: Canlı koruma modülü kontrolü
RegisterCommand("onlyac_protect", function(src, args)
    if src ~= 0 and not ONLY_AC.IsBypass(src) then
        TriggerClientEvent("chat:addMessage", src, { color = {255, 0, 0}, args = {"ONLY AC", "Bu komutu kullanma yetkiniz yok!"} })
        return
    end

    local moduleName = args[1]
    local state = args[2]

    if not moduleName or (state ~= "on" and state ~= "off") then
        local msg = "Kullanım: /onlyac_protect <ModülAdı> <on/off> (Örn: /onlyac_protect AntiGodmode off)"
        if src == 0 then print(msg) else TriggerClientEvent("chat:addMessage", src, { color = {255, 255, 0}, args = {"ONLY AC", msg} }) end
        return
    end

    local boolState = (state == "on")
    if Config.Protections[moduleName] == nil then
        local msg = ("Hata: '%s' adında bir koruma modülü bulunamadı!"):format(moduleName)
        if src == 0 then print(msg) else TriggerClientEvent("chat:addMessage", src, { color = {255, 100, 100}, args = {"ONLY AC", msg} }) end
        return
    end

    Config.Protections[moduleName] = boolState
    local msg = ("[ONLY AC] '%s' koruması %s olarak ayarlandı."):format(moduleName, boolState and "AÇIK" or "KAPALI")
    if src == 0 then print(msg) else TriggerClientEvent("chat:addMessage", src, { color = {0, 255, 150}, args = {"ONLY AC", msg} }) end
end, false)

-- /onlyac_clear <vehicles|peds|props|all>: Harita Temizleme & Optimizasyon (FeloxAC v2.0 Standardı)
RegisterCommand("onlyac_clear", function(src, args)
    if src ~= 0 and not ONLY_AC.IsBypass(src) then
        TriggerClientEvent("chat:addMessage", src, { color = {255, 0, 0}, args = {"ONLY AC", "Bu komutu kullanma yetkiniz yok!"} })
        return
    end

    local targetType = args[1] and args[1]:lower() or "all"
    local count = 0

    if targetType == "vehicles" or targetType == "all" then
        local vehicles = GetAllVehicles()
        for _, veh in ipairs(vehicles) do
            if DoesEntityExist(veh) then
                local hasDriver = false
                for i = -1, 4 do
                    if GetPedInVehicleSeat(veh, i) ~= 0 then hasDriver = true break end
                end
                if not hasDriver then
                    DeleteEntity(veh)
                    count = count + 1
                end
            end
        end
    end

    if targetType == "peds" or targetType == "all" then
        local peds = GetAllPeds()
        for _, ped in ipairs(peds) do
            if DoesEntityExist(ped) and not IsPedAPlayer(ped) then
                DeleteEntity(ped)
                count = count + 1
            end
        end
    end

    if targetType == "props" or targetType == "all" then
        local objects = GetAllObjects()
        for _, obj in ipairs(objects) do
            if DoesEntityExist(obj) then
                local model = GetEntityModel(obj)
                if not Config.ObjectWhitelist or not Config.ObjectWhitelist[model] then
                    DeleteEntity(obj)
                    count = count + 1
                end
            end
        end
    end

    local resultMsg = ("[ONLY AC Harita Temizliği] %s türündeki %s adet sahipsiz entity temizlendi."):format(targetType:upper(), count)
    if src == 0 then
        print(resultMsg)
    else
        TriggerClientEvent("chat:addMessage", src, { color = {0, 255, 128}, args = {"ONLY AC", resultMsg} })
    end
end, false)

-- =========================================================================
-- EXPORTS
-- =========================================================================
exports("DetectPlayer", function(src, reason, details, action)
    ONLY_AC.Detect(src, reason, details, action)
end)

exports("GetStats", function()
    return ONLY_AC.Stats
end)

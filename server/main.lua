-- =========================================================================
-- 465 AC v4.2.0 - SUNUCU ANA MODÜL & GÜVENLİK YÖNETİCİSİ
-- Dinamik Token, Heartbeat Cross-Check, Modül Profilleri, Event Guard & Komutlar
-- =========================================================================

math.randomseed(os.time() + math.floor(os.clock() * 1000))

AC465 = {}
AC465.RecentLogs = {}
AC465.Stats = {
    totalDetections = 0,
    totalBans = 0,
    totalKicks = 0,
    startTime = os.time()
}

local clientTokens = {}
local clientNonces = {}
local playerLastHeartbeat = {}
local teleportGraceUntil = {}
local txAdminBypass = {}
local actionLocks = {}
local eventRateTracker = {}

-- txAdmin yetkili otorite senkronizasyonu
AddEventHandler("txAdmin:events:adminAuth", function(data)
    if data and data.netid then
        local src = tonumber(data.netid)
        if src and src > 0 then
            txAdminBypass[src] = (data.isAdmin == true)
        end
    end
end)

-- Yetkili / Bypass kontrolü (465ac.bypass + AutoTxAdminBypass)
function AC465.IsBypass(src)
    if not src or src == 0 then return true end
    if Config.AcePermission and Config.AcePermission ~= "" and IsPlayerAceAllowed(src, Config.AcePermission) then
        return true
    end
    if AC465_Shared.IsModuleEnabled("AutoTxAdminBypass") then
        if txAdminBypass[src] or IsPlayerAceAllowed(src, "txadmin.all") or IsPlayerAceAllowed(src, "command") then
            return true
        end
    end
    return false
end

function AC465.GetLastHeartbeat(src)
    return playerLastHeartbeat[src]
end

function AC465.AllowTeleport(src, durationMs)
    local ms = tonumber(durationMs) or 5000
    teleportGraceUntil[src] = GetGameTimer() + math.min(math.max(ms, 500), 30000)
    TriggerClientEvent("ac465:client:allowTeleport", src, ms)
end

-- Tüm istemcilere canlı koruma profillerini senkronize et
function AC465.BroadcastProtections()
    TriggerClientEvent("ac465:client:syncProtections", -1, Config.Protections)
end

-- Ortak güvenli harita temizliği (Hem komut hem Web Panel kullanır)
function AC465.ClearEntities(targetType)
    targetType = (targetType and tostring(targetType):lower()) or "all"
    local count = 0

    if targetType == "vehicles" or targetType == "all" then
        for _, veh in ipairs(GetAllVehicles()) do
            if DoesEntityExist(veh) then
                local occupied = false
                for seat = -1, 4 do
                    if GetPedInVehicleSeat(veh, seat) ~= 0 then
                        occupied = true
                        break
                    end
                end
                if not occupied then
                    DeleteEntity(veh)
                    count = count + 1
                end
            end
        end
    end

    if targetType == "peds" or targetType == "all" then
        for _, ped in ipairs(GetAllPeds()) do
            if DoesEntityExist(ped) and not IsPedAPlayer(ped) then
                DeleteEntity(ped)
                count = count + 1
            end
        end
    end

    if targetType == "props" or targetType == "all" then
        for _, obj in ipairs(GetAllObjects()) do
            if DoesEntityExist(obj) then
                local model = GetEntityModel(obj)
                if not Config.ObjectWhitelist or not Config.ObjectWhitelist[model] then
                    DeleteEntity(obj)
                    count = count + 1
                end
            end
        end
    end

    return count
end

function AC465.SendDiscordLog(src, reason, details, action, screenshotUrl)
    if not Config.DiscordWebhook or Config.DiscordWebhook == "" or Config.DiscordWebhook:sub(1, 4) ~= "http" then
        return
    end

    local playerName = GetPlayerName(src) or "Bilinmeyen"
    local ids = BanSystem.GetIdentifiers(src)
    local ping = GetPlayerPing(src) or 0

    local fields = {
        { name = "Oyuncu Adı", value = ("`%s` (ID: %s)"):format(playerName, src), inline = true },
        { name = "Eylem Profili", value = ("`%s`"):format(tostring(action):upper()), inline = true },
        { name = "Ping", value = ("`%s ms`"):format(ping), inline = true },
        { name = "Tespit Nedeni", value = ("**%s**"):format(reason), inline = false },
        { name = "Detay", value = ("```%s```"):format(details or "Detay yok"), inline = false },
        { name = "Discord", value = ids.discord ~= "N/A" and ("<@%s>"):format(ids.discord:gsub("discord:", "")) or "`N/A`", inline = true },
        { name = "FiveM License", value = ("`%s`"):format(ids.license), inline = true },
        { name = "Steam ID", value = ("`%s`"):format(ids.steam), inline = true }
    }

    local embed = {{
        color = Config.EmbedColor or 9227186,
        title = "🛡️ " .. (Config.ServerName or "465 AC") .. " - Güvenlik Raporu",
        description = "Koruma modülü şüpheli bir eylem raporladı.",
        fields = fields,
        footer = { text = ("465 AC v%s | %s"):format(Config.Version or "4.2.0", os.date("%Y-%m-%d %H:%M:%S")) }
    }}

    if screenshotUrl and screenshotUrl ~= "" then
        embed[1].image = { url = screenshotUrl }
    end

    PerformHttpRequest(Config.DiscordWebhook, function() end, "POST", json.encode({
        username = Config.ServerName or "465 AC",
        embeds = embed
    }), { ["Content-Type"] = "application/json" })
end

local function executeAction(src, reason, action)
    if action == "ban" then
        AC465.Stats.totalBans = AC465.Stats.totalBans + 1
        BanSystem.AddBan(src, reason)
    elseif action == "kick" then
        AC465.Stats.totalKicks = AC465.Stats.totalKicks + 1
        if GetPlayerName(src) then
            DropPlayer(src, ("\n[465 AC v4.2.0] Sunucudan Atıldınız!\nSebep: %s"):format(reason))
        end
    end
end

-- Tespit & Modül Aksiyon Çözümleyici (off | log | kick | ban)
function AC465.Detect(src, reason, details, customActionOrModule, moduleName)
    if not src or src <= 0 or AC465.IsBypass(src) then
        return
    end

    local action
    if moduleName then
        action = AC465_Shared.GetModuleAction(moduleName, customActionOrModule)
    elseif customActionOrModule == "off" or customActionOrModule == "log" or customActionOrModule == "kick" or customActionOrModule == "ban" then
        action = customActionOrModule
    elseif customActionOrModule and Config.Protections[customActionOrModule] ~= nil then
        action = AC465_Shared.GetModuleAction(customActionOrModule)
    else
        action = Config.DefaultAction or "ban"
    end

    if action == "off" then
        return
    end

    -- Atılma / banlanma aşamasındaki oyuncu için mükerrer işlemi önle
    local nowMs = GetGameTimer()
    if (action == "kick" or action == "ban") and actionLocks[src] and (nowMs - actionLocks[src]) < 4000 then
        return
    end
    if action == "kick" or action == "ban" then
        actionLocks[src] = nowMs
    end

    local playerName = GetPlayerName(src) or "Bilinmeyen"
    print(("^1[465 AC TESPİT]^0 [%s] %s (ID: %s) -> Sebep: %s | Detay: %s"):format(
        action:upper(), playerName, src, reason, details or "Yok"
    ))

    AC465.Stats.totalDetections = AC465.Stats.totalDetections + 1
    table.insert(AC465.RecentLogs, 1, {
        time = os.date("%H:%M:%S"),
        player = playerName .. " (ID " .. src .. ")",
        reason = reason,
        details = details or "Yok",
        action = action
    })
    if #AC465.RecentLogs > 60 then
        table.remove(AC465.RecentLogs, #AC465.RecentLogs)
    end

    -- screenshot-basic varsa ban/kick öncesi kısa süre içinde ekran görüntüsü dene
    if Config.ScreenCaptureEnabled and GetResourceState("screenshot-basic") == "started" and GetPlayerName(src) then
        local handled = false
        local ok = pcall(function()
            exports["screenshot-basic"]:requestClientScreenshot(src, {}, function(err, data)
                if handled then return end
                handled = true
                local imgUrl = (type(data) == "string" and data:sub(1, 4) == "http") and data or nil
                AC465.SendDiscordLog(src, reason, details, action, imgUrl)
                executeAction(src, reason, action)
            end)
        end)
        if not ok then
            AC465.SendDiscordLog(src, reason, details, action, nil)
            executeAction(src, reason, action)
            return
        end
        SetTimeout(1100, function()
            if not handled then
                handled = true
                AC465.SendDiscordLog(src, reason, details, action, nil)
                executeAction(src, reason, action)
            end
        end)
    else
        AC465.SendDiscordLog(src, reason, details, action, nil)
        executeAction(src, reason, action)
    end
end

local function generateToken(src)
    local token = ("AC465-%s-%s-%06d"):format(src, os.time(), math.random(100000, 999999))
    clientTokens[src] = token
    return token
end

RegisterNetEvent("ac465:client:requestHandshake", function()
    local src = source
    local token = generateToken(src)
    clientNonces[src] = 0
    playerLastHeartbeat[src] = os.time()
    TriggerClientEvent("ac465:client:handshakeResponse", src, token, AC465_Shared.BuildClientConfig())
end)

-- Sunucu Taraflı Heartbeat & Fizik / Ölümsüzlük Cross-Check
RegisterNetEvent("ac465:client:heartbeat", function(token, data)
    local src = source
    if not clientTokens[src] or clientTokens[src] ~= token then return end
    playerLastHeartbeat[src] = os.time()

    if AC465.IsBypass(src) then return end

    local ped = GetPlayerPed(src)
    if not DoesEntityExist(ped) then return end

    -- 1. Koordinat manipülasyonu cross-check (Teleport Grace hariç)
    local inTpGrace = teleportGraceUntil[src] and (GetGameTimer() < teleportGraceUntil[src])
    if data and type(data) == "table" and data.coords and not inTpGrace then
        local srvCoords = GetEntityCoords(ped)
        local cliCoords = vector3(tonumber(data.coords.x) or 0, tonumber(data.coords.y) or 0, tonumber(data.coords.z) or 0)
        local diff = #(srvCoords - cliCoords)
        if diff > 160.0 and not AC465_Shared.IsInExcludeZone(srvCoords) then
            AC465.Detect(src, "Koordinat Sahteciliği (Coords Desync / Spoofing)", ("Fark: %.1f metre"):format(diff), "kick", "AntiTeleport")
            return
        end
    end

    -- 2. Doğrudan FXServer Otorite Kontrolleri (İstemci scripti manipüle edilse bile çalışır)
    if AC465_Shared.IsModuleEnabled("AntiGodmode") and GetPlayerInvincible and GetPlayerInvincible(src) then
        AC465.Detect(src, "Sunucu Doğrulamalı Ölümsüzlük (Server-Side Invincible)", "GetPlayerInvincible == true", nil, "AntiGodmode")
    end
end)

RegisterNetEvent("ac465:server:reportDetection", function(token, reason, details, nonce, moduleName)
    local src = source
    if not clientTokens[src] or clientTokens[src] ~= token then
        AC465.Detect(src, "Geçersiz Güvenlik Belirteci (Token Sahteciliği)", "Token mismatch", "ban")
        return
    end

    if nonce ~= nil then
        local lastNonce = clientNonces[src] or 0
        if type(nonce) ~= "number" or nonce <= lastNonce then
            AC465.Detect(src, "Geçersiz Rapor Sıralaması (Nonce Replay)", ("Nonce: %s | Son: %s"):format(tostring(nonce), tostring(lastNonce)), "ban")
            return
        end
        clientNonces[src] = nonce
    end

    AC465.Detect(src, reason or "Şüpheli İstemci Aktivitesi", details, nil, moduleName)
end)

RegisterNetEvent("ac465:server:resourceStopped", function(token)
    local src = source
    if clientTokens[src] and clientTokens[src] == token then
        AC465.Detect(src, "Anti-Cheat Kaynağı Durduruldu (Resource Stop)", "İstemci script durdurma sinyali", "kick", "AntiResourceStop")
    end
end)

RegisterNetEvent("ac465:server:suspiciousResourceStart", function(token, resourceName)
    local src = source
    if clientTokens[src] and clientTokens[src] == token then
        AC465.Detect(src, "Yetkisiz Resource Enjeksiyonu", ("Başlatılan Paket: %s"):format(tostring(resourceName)), "kick", "AntiResourceInjection")
    end
end)

-- Bal Küpü (Honeypot) Eventleri
if Config.HoneypotEvents then
    for _, eventName in ipairs(Config.HoneypotEvents) do
        RegisterNetEvent(eventName, function()
            local src = source
            if AC465_Shared.IsModuleEnabled("AntiHoneypotEvents") then
                AC465.Detect(src, "Bal Küpü (Honeypot Event) Tetiklendi", ("Event: %s"):format(eventName), "ban", "AntiHoneypotEvents")
            end
        end)
    end
end

-- Event Flooding & Anti-Dupe Hız Limiti (Config.EventTriggerGuard)
if Config.EventTriggerGuard and Config.EventTriggerGuard.Enabled and Config.EventTriggerGuard.WatchedEvents then
    for _, evName in ipairs(Config.EventTriggerGuard.WatchedEvents) do
        AddEventHandler(evName, function()
            local src = source
            if not src or src <= 0 or AC465.IsBypass(src) then return end
            if not AC465_Shared.IsModuleEnabled("AntiDupe") then return end

            local nowMs = GetGameTimer()
            local rec = eventRateTracker[src]
            if not rec or (nowMs - rec.ts) > 1000 then
                eventRateTracker[src] = { ts = nowMs, count = 1 }
            else
                rec.count = rec.count + 1
                if rec.count > (Config.EventTriggerGuard.MaxTriggersPerSecond or 8) then
                    CancelEvent()
                    AC465.Detect(src, "Event Flooding / Ekonomi Dupe Girişimi", ("Event: %s (%s/sn)"):format(evName, rec.count), "ban", "AntiDupe")
                end
            end
        end)
    end
end

AddEventHandler("playerDropped", function()
    local src = source
    clientTokens[src] = nil
    clientNonces[src] = nil
    playerLastHeartbeat[src] = nil
    teleportGraceUntil[src] = nil
    txAdminBypass[src] = nil
    actionLocks[src] = nil
    eventRateTracker[src] = nil
    if AC465.ThreatScores then AC465.ThreatScores[src] = nil end
end)

-- =========================================================================
-- YETKİLİ KOMUTLARI (/465ac_*)
-- =========================================================================
local function replyCmd(src, msg, color)
    if src == 0 then
        print(msg)
    else
        TriggerClientEvent("chat:addMessage", src, { color = color or {140, 203, 178}, args = {"465 AC", msg} })
    end
end

local function cmdCheck(src, args)
    if src ~= 0 and not AC465.IsBypass(src) then return replyCmd(src, "Yetkiniz yok!", {255, 80, 80}) end
    local target = tonumber(args[1])
    if not target or not GetPlayerName(target) then return replyCmd(src, "Kullanım: /465ac_check <oyuncu_id>", {255, 220, 80}) end
    local ped = GetPlayerPed(target)
    local coords = DoesEntityExist(ped) and GetEntityCoords(ped) or vector3(0, 0, 0)
    local health = DoesEntityExist(ped) and GetEntityHealth(ped) or 0
    local armor = DoesEntityExist(ped) and GetPedArmour(ped) or 0
    local ids = BanSystem.GetIdentifiers(target)
    replyCmd(src, ("\n[465 AC OYUNCU - ID %s]\nİsim: %s | Ping: %sms | Can: %s | Zırh: %s\nKonum: %.1f, %.1f, %.1f\nDiscord: %s | License: %s"):format(
        target, GetPlayerName(target), GetPlayerPing(target) or 0, health, armor, coords.x, coords.y, coords.z, ids.discord, ids.license
    ))
end
RegisterCommand("465ac_check", cmdCheck, false)

local function cmdStats(src)
    if src ~= 0 and not AC465.IsBypass(src) then return replyCmd(src, "Yetkiniz yok!", {255, 80, 80}) end
    local up = os.time() - (AC465.Stats.startTime or os.time())
    replyCmd(src, ("[465 AC v4.2.0] Uptime: %sh %sd %ss | Tespit: %s | Ban: %s | Kick: %s | Aktif: %s"):format(
        math.floor(up / 3600), math.floor((up % 3600) / 60), up % 60,
        AC465.Stats.totalDetections, AC465.Stats.totalBans, AC465.Stats.totalKicks, #GetPlayers()
    ))
end
RegisterCommand("465ac_stats", cmdStats, false)

local function cmdKick(src, args)
    if src ~= 0 and not AC465.IsBypass(src) then return replyCmd(src, "Yetkiniz yok!", {255, 80, 80}) end
    local target = tonumber(args[1])
    if not target or not GetPlayerName(target) then return replyCmd(src, "Kullanım: /465ac_kick <id> <sebep>", {255, 220, 80}) end
    table.remove(args, 1)
    local reason = table.concat(args, " ")
    AC465.Detect(target, "Yetkili Komutu (Kick)", reason ~= "" and reason or "Yetkili tarafından atıldınız", "kick")
end
RegisterCommand("465ac_kick", cmdKick, false)

local function cmdBan(src, args)
    if src ~= 0 and not AC465.IsBypass(src) then return replyCmd(src, "Yetkiniz yok!", {255, 80, 80}) end
    local target = tonumber(args[1])
    if not target or not GetPlayerName(target) then return replyCmd(src, "Kullanım: /465ac_ban <id> <sebep>", {255, 220, 80}) end
    table.remove(args, 1)
    local reason = table.concat(args, " ")
    AC465.Detect(target, "Yetkili Komutu (Ban)", reason ~= "" and reason or "Yetkili tarafından yasaklandınız", "ban")
end
RegisterCommand("465ac_ban", cmdBan, false)

local function cmdProtect(src, args)
    if src ~= 0 and not AC465.IsBypass(src) then return replyCmd(src, "Yetkiniz yok!", {255, 80, 80}) end
    local moduleName = args[1]
    local state = args[2] and args[2]:lower()
    local valMap = { on = true, ["true"] = true, ban = "ban", kick = "kick", log = "log", off = "off", ["false"] = "off" }
    if not moduleName or valMap[state] == nil then
        return replyCmd(src, "Kullanım: /465ac_protect <Modül> <on|off|log|kick|ban>", {255, 220, 80})
    end
    if Config.Protections[moduleName] == nil then
        return replyCmd(src, ("Modül bulunamadı: %s"):format(moduleName), {255, 80, 80})
    end
    Config.Protections[moduleName] = valMap[state]
    AC465.BroadcastProtections()
    replyCmd(src, ("'%s' modülü '%s' olarak güncellendi."):format(moduleName, tostring(state)))
end
RegisterCommand("465ac_protect", cmdProtect, false)

local function cmdClear(src, args)
    if src ~= 0 and not AC465.IsBypass(src) then return replyCmd(src, "Yetkiniz yok!", {255, 80, 80}) end
    local targetType = args[1] and args[1]:lower() or "all"
    local cleared = AC465.ClearEntities(targetType)
    replyCmd(src, ("[Harita Temizliği] %s kategorisinde %s adet sahipsiz entity temizlendi."):format(targetType:upper(), cleared))
end
RegisterCommand("465ac_clear", cmdClear, false)

-- Exports (Harici script uyumluluğu)
exports("DetectPlayer", function(src, reason, details, action, moduleName) AC465.Detect(src, reason, details, action, moduleName) end)
exports("AllowTeleport", function(src, durationMs) AC465.AllowTeleport(src, durationMs) end)
exports("GetStats", function() return AC465.Stats end)

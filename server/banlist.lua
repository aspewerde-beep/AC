-- =========================================================================
-- ONLY AC v3.0.0 (ULTIMATE EDITION) - GÜVENLİ YASAKLAMA (BAN) YÖNETİMİ
-- =========================================================================

BanSystem = {}
local bans = {}
local banFile = "bans.json"

-- Ban listesini dosyadan yükle
local function loadBans()
    local content = LoadResourceFile(GetCurrentResourceName(), banFile)
    if content and content ~= "" then
        local success, decoded = pcall(json.decode, content)
        if success and type(decoded) == "table" then
            bans = decoded
            print(("^2[ONLY AC v3.0.0]^0 %s adet aktif ban kaydı yüklendi."):format(#bans))
            return
        end
    end
    bans = {}
    SaveResourceFile(GetCurrentResourceName(), banFile, json.encode(bans, { indent = true }), -1)
end

-- Ban listesini dosyaya kaydet
local function saveBans()
    SaveResourceFile(GetCurrentResourceName(), banFile, json.encode(bans, { indent = true }), -1)
end

-- Oyuncunun tüm tanımlayıcılarını ve HWID tokenlarını topla
function BanSystem.GetIdentifiers(src)
    local ids = {
        steam = "N/A",
        license = "N/A",
        discord = "N/A",
        xbl = "N/A",
        live = "N/A",
        ip = "N/A",
        tokens = {}
    }

    local numIds = GetNumPlayerIdentifiers(src)
    for i = 0, numIds - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id then
            if string.find(id, "steam:") then ids.steam = id
            elseif string.find(id, "license:") then ids.license = id
            elseif string.find(id, "discord:") then ids.discord = id
            elseif string.find(id, "xbl:") then ids.xbl = id
            elseif string.find(id, "live:") then ids.live = id
            elseif string.find(id, "ip:") then ids.ip = id
            end
        end
    end

    -- FiveM HWID Donanım Belirteçleri (Tokens)
    local numTokens = GetNumPlayerTokens and GetNumPlayerTokens(src) or 0
    for i = 0, numTokens - 1 do
        local token = GetPlayerToken(src, i)
        if token then
            table.insert(ids.tokens, token)
        end
    end

    return ids
end

-- Yeni ban ekle (Kalıcı veya Süreli)
function BanSystem.AddBan(src, reason, duration, bannedBy)
    local ids = BanSystem.GetIdentifiers(src)
    local playerName = GetPlayerName(src) or "Bilinmeyen"
    local banId = "OAC-" .. tostring(os.time()) .. "-" .. tostring(math.random(1000, 9999))
    local currentTime = os.time()
    local expireTime = (duration and duration > 0) and (currentTime + duration) or "PERMANENT"

    local banRecord = {
        id = banId,
        name = playerName,
        reason = reason or "Hile / Yasaklı Eylem Tespiti",
        identifiers = ids,
        bannedBy = bannedBy or "ONLY AC Koruma Sistemi",
        date = os.date("%Y-%m-%d %H:%M:%S"),
        expire = expireTime
    }

    table.insert(bans, banRecord)
    saveBans()

    local expireStr = (expireTime == "PERMANENT") and "KALICI (PERMANENT)" or os.date("%Y-%m-%d %H:%M:%S", expireTime)

    DropPlayer(src, ("\n[ONLY AC v3.0.0] Sunucudan Yasaklandınız!\nBan ID: %s\nSebep: %s\nSüre: %s\nYetkili: %s\nİtiraz için Discord üzerinden yetkililere ulaşın."):format(
        banId, banRecord.reason, expireStr, banRecord.bannedBy
    ))
    return banRecord
end

-- Oyuncu girişinde ban kontrolü (Deferrals)
AddEventHandler("playerConnecting", function(name, setKickReason, deferrals)
    deferrals.defer()
    local src = source
    Wait(50)
    deferrals.update("[ONLY AC v3.0.0] Güvenlik doğrulaması yapılıyor...")

    local playerIds = BanSystem.GetIdentifiers(src)
    local currentTime = os.time()
    local isBanned = false
    local matchedBan = nil

    for _, ban in ipairs(bans) do
        -- Süreli ban kontrolü
        if ban.expire ~= "PERMANENT" and type(ban.expire) == "number" and currentTime > ban.expire then
            -- Ban süresi dolmuş, atla
        else
            -- 1. Standart Tanımlayıcı Kontrolleri (License, Steam, Discord, Live, XBL, IP)
            for idType, idVal in pairs(playerIds) do
                if idType ~= "tokens" and idVal ~= "N/A" and ban.identifiers[idType] == idVal then
                    isBanned = true
                    matchedBan = ban
                    break
                end
            end

            -- 2. HWID Token Karşılaştırması (Donanım Banı)
            if not isBanned and ban.identifiers.tokens and #ban.identifiers.tokens > 0 and #playerIds.tokens > 0 then
                for _, bToken in ipairs(ban.identifiers.tokens) do
                    for _, pToken in ipairs(playerIds.tokens) do
                        if bToken == pToken then
                            isBanned = true
                            matchedBan = ban
                            break
                        end
                    end
                    if isBanned then break end
                end
            end
        end

        if isBanned then break end
    end

    if isBanned and matchedBan then
        local expireStr = (matchedBan.expire == "PERMANENT") and "Kalıcı" or (type(matchedBan.expire) == "number" and os.date("%Y-%m-%d %H:%M:%S", matchedBan.expire) or tostring(matchedBan.expire))
        deferrals.done(("\n[ONLY AC v3.0.0] Bu sunucuya girişiniz engellenmiştir.\nBan ID: %s\nSebep: %s\nTarih: %s\nBitiş: %s\nYasaklayan: %s"):format(
            matchedBan.id,
            matchedBan.reason,
            matchedBan.date,
            expireStr,
            matchedBan.bannedBy or "ONLY AC"
        ))
    else
        deferrals.done()
    end
end)

-- Süresi dolmuş banları otomatik temizleme döngüsü (30 dakikada bir)
CreateThread(function()
    while true do
        Wait(1800000) -- 30 dakika
        local currentTime = os.time()
        local count = 0
        for i = #bans, 1, -1 do
            if bans[i].expire ~= "PERMANENT" and type(bans[i].expire) == "number" and currentTime > bans[i].expire then
                table.remove(bans, i)
                count = count + 1
            end
        end
        if count > 0 then
            saveBans()
            print(("^2[ONLY AC v3.0.0]^0 Süresi dolan %s adet süreli ban kaydı otomatik temizlendi."):format(count))
        end
    end
end)

-- Konsol komutu ile unban (/onlyac_unban <Ban-ID>)
RegisterCommand("onlyac_unban", function(source, args)
    if source ~= 0 and (not ONLY_AC or not ONLY_AC.IsBypass(source)) then
        print("^1[ONLY AC] Bu komutu kullanma yetkiniz yok.^0")
        return
    end
    local targetId = args[1]
    if not targetId then
        print("^3Kullanım: onlyac_unban <Ban-ID>^0")
        return
    end

    local removed = BanSystem.RemoveBan(targetId)
    if removed then
        print(("^2[ONLY AC] %s ID'li ban kaydı başarıyla kaldırıldı.^0"):format(targetId))
    else
        print(("^1[ONLY AC] %s ID'li ban kaydı bulunamadı.^0"):format(targetId))
    end
end, false)

-- Süreli ban komutu (/onlyac_tempban <id> <saat> <sebep>)
RegisterCommand("onlyac_tempban", function(source, args)
    if source ~= 0 and (not ONLY_AC or not ONLY_AC.IsBypass(source)) then
        print("^1[ONLY AC] Bu komutu kullanma yetkiniz yok.^0")
        return
    end

    local target = tonumber(args[1])
    local hours = tonumber(args[2])
    if not target or not hours or hours <= 0 or not GetPlayerName(target) then
        local msg = "Kullanım: /onlyac_tempban <oyuncu_id> <sure_saat> <sebep>"
        if source == 0 then print(msg) else TriggerClientEvent("chat:addMessage", source, { color = {255, 255, 0}, args = {"ONLY AC", msg} }) end
        return
    end

    table.remove(args, 1)
    table.remove(args, 1)
    local reason = table.concat(args, " ")
    if reason == "" then reason = "Yetkili tarafından süreli yasaklama" end

    local adminName = (source == 0) and "Konsol" or GetPlayerName(source)
    local durationSec = hours * 3600
    BanSystem.AddBan(target, reason, durationSec, adminName)

    print(("^2[ONLY AC]^0 %s (ID %s), %s saat süreyle yasaklandı. Sebep: %s"):format(GetPlayerName(target) or "Bilinmeyen", target, hours, reason))
end, false)

-- Başlangıçta banları yükle
CreateThread(function()
    loadBans()
end)

-- Export fonksiyonları
function BanSystem.RemoveBan(targetId)
    for i = #bans, 1, -1 do
        if bans[i].id == targetId then
            table.remove(bans, i)
            saveBans()
            return true
        end
    end
    return false
end

function BanSystem.GetBans()
    return bans
end

exports("BanPlayer", function(src, reason, duration, bannedBy)
    return BanSystem.AddBan(src, reason, duration, bannedBy)
end)

exports("GetBans", function()
    return bans
end)

exports("RemoveBan", function(banId)
    return BanSystem.RemoveBan(banId)
end)

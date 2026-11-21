-- =========================================================================
-- 465 AC v4.2.0 - YASAKLAMA (BAN) VE DONANIM TOKEN YÖNETİMİ
-- Kalıcı / Süreli Ban, HWID Token Eşleştirme & İstihbarat Senkronizasyonu
-- =========================================================================

BanSystem = {}
local bans = {}
local banFile = "bans.json"

local function loadBans()
    local content = LoadResourceFile(GetCurrentResourceName(), banFile)
    if content and content ~= "" then
        local success, decoded = pcall(json.decode, content)
        if success and type(decoded) == "table" then
            bans = decoded
            print(("^2[465 AC v4.2.0]^0 %s adet aktif ban kaydı yüklendi."):format(#bans))
            return
        end
    end
    bans = {}
    SaveResourceFile(GetCurrentResourceName(), banFile, json.encode(bans, { indent = true }), -1)
end

local function saveBans()
    SaveResourceFile(GetCurrentResourceName(), banFile, json.encode(bans, { indent = true }), -1)
end

function BanSystem.GetIdentifiers(src)
    local ids = {
        steam = "N/A",
        license = "N/A",
        license2 = "N/A",
        discord = "N/A",
        fivem = "N/A",
        xbl = "N/A",
        live = "N/A",
        ip = "N/A",
        tokens = {}
    }

    local numIds = GetNumPlayerIdentifiers(src)
    for i = 0, numIds - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id then
            if id:sub(1, 6) == "steam:" then ids.steam = id
            elseif id:sub(1, 8) == "license:" then ids.license = id
            elseif id:sub(1, 9) == "license2:" then ids.license2 = id
            elseif id:sub(1, 8) == "discord:" then ids.discord = id
            elseif id:sub(1, 6) == "fivem:" then ids.fivem = id
            elseif id:sub(1, 4) == "xbl:" then ids.xbl = id
            elseif id:sub(1, 5) == "live:" then ids.live = id
            elseif id:sub(1, 3) == "ip:" then ids.ip = id
            end
        end
    end

    local numTokens = GetNumPlayerTokens and GetNumPlayerTokens(src) or 0
    for i = 0, numTokens - 1 do
        local token = GetPlayerToken(src, i)
        if token then
            table.insert(ids.tokens, token)
        end
    end

    return ids
end

function BanSystem.AddBan(src, reason, duration, bannedBy)
    local ids = BanSystem.GetIdentifiers(src)
    local playerName = GetPlayerName(src) or "Bilinmeyen"
    local banId = "465-" .. tostring(os.time()) .. "-" .. tostring(math.random(1000, 9999))
    local currentTime = os.time()
    local expireTime = (duration and duration > 0) and (currentTime + duration) or "PERMANENT"

    local banRecord = {
        id = banId,
        name = playerName,
        reason = reason or "Hile / Yasaklı Eylem Tespiti",
        identifiers = ids,
        bannedBy = bannedBy or "465 AC Koruma Sistemi",
        date = os.date("%Y-%m-%d %H:%M:%S"),
        expire = expireTime
    }

    table.insert(bans, banRecord)
    saveBans()

    -- Oyuncu geçmişinde yasaklı bayrağını işaretle (Ban Evasion tespitini aktif tut)
    if Intelligence and Intelligence.MarkBanned and ids.license ~= "N/A" then
        Intelligence.MarkBanned(ids.license, true)
    end

    local expireStr = (expireTime == "PERMANENT") and "KALICI (PERMANENT)" or os.date("%Y-%m-%d %H:%M:%S", expireTime)
    if GetPlayerName(src) then
        DropPlayer(src, ("\n[465 AC v4.2.0] Sunucudan Yasaklandınız!\nBan ID: %s\nSebep: %s\nSüre: %s\nYetkili: %s"):format(
            banId, banRecord.reason, expireStr, banRecord.bannedBy
        ))
    end
    return banRecord
end

AddEventHandler("playerConnecting", function(name, setKickReason, deferrals)
    deferrals.defer()
    local src = source
    Wait(50)
    deferrals.update("[465 AC] Güvenlik & Ban kontrolü yapılıyor...")

    local playerIds = BanSystem.GetIdentifiers(src)
    local currentTime = os.time()
    local matchedBan = nil

    for _, ban in ipairs(bans) do
        if ban.expire == "PERMANENT" or type(ban.expire) ~= "number" or currentTime <= ban.expire then
            for idType, idVal in pairs(playerIds) do
                if idType ~= "tokens" and idVal ~= "N/A" and ban.identifiers and ban.identifiers[idType] == idVal then
                    matchedBan = ban
                    break
                end
            end

            if not matchedBan and ban.identifiers and ban.identifiers.tokens and #ban.identifiers.tokens > 0 and #playerIds.tokens > 0 then
                local lookupTokens = {}
                for _, t in ipairs(ban.identifiers.tokens) do lookupTokens[t] = true end
                for _, pToken in ipairs(playerIds.tokens) do
                    if lookupTokens[pToken] then
                        matchedBan = ban
                        break
                    end
                end
            end
        end
        if matchedBan then break end
    end

    if matchedBan then
        local expireStr = (matchedBan.expire == "PERMANENT") and "Kalıcı" or (type(matchedBan.expire) == "number" and os.date("%Y-%m-%d %H:%M:%S", matchedBan.expire) or tostring(matchedBan.expire))
        deferrals.done(("\n[465 AC v4.2.0] Bu sunucuya girişiniz engellenmiştir.\nBan ID: %s\nSebep: %s\nTarih: %s\nBitiş: %s\nYasaklayan: %s"):format(
            matchedBan.id,
            matchedBan.reason,
            matchedBan.date,
            expireStr,
            matchedBan.bannedBy or "465 AC"
        ))
        return
    end

    -- Banlı değilse tehdit istihbaratı & alt hesap kontrolünü çalıştır
    if Intelligence and Intelligence.EvaluateConnection then
        local blocked, blockReason = Intelligence.EvaluateConnection(src, playerIds)
        if blocked then
            deferrals.done(blockReason)
            return
        end
    end

    deferrals.done()
end)

-- Süresi dolmuş banları otomatik temizleme döngüsü (30 dakika)
CreateThread(function()
    while true do
        Wait(1800000)
        local currentTime = os.time()
        local count = 0
        for i = #bans, 1, -1 do
            if bans[i].expire ~= "PERMANENT" and type(bans[i].expire) == "number" and currentTime > bans[i].expire then
                local lic = bans[i].identifiers and bans[i].identifiers.license
                table.remove(bans, i)
                count = count + 1
                if lic and Intelligence and Intelligence.MarkBanned then
                    Intelligence.MarkBanned(lic, false)
                end
            end
        end
        if count > 0 then
            saveBans()
            print(("^2[465 AC v4.2.0]^0 Süresi dolan %s adet ban kaydı otomatik temizlendi."):format(count))
        end
    end
end)

function BanSystem.RemoveBan(targetId)
    for i = #bans, 1, -1 do
        if bans[i].id == targetId then
            local lic = bans[i].identifiers and bans[i].identifiers.license
            table.remove(bans, i)
            saveBans()
            if lic and Intelligence and Intelligence.MarkBanned then
                Intelligence.MarkBanned(lic, false)
            end
            return true
        end
    end
    return false
end

function BanSystem.GetBans()
    return bans
end

local function handleUnbanCmd(source, args)
    if source ~= 0 and (not ONLY_AC or not ONLY_AC.IsBypass(source)) then
        print("^1[465 AC] Bu komutu kullanma yetkiniz yok.^0")
        return
    end
    local targetId = args[1]
    if not targetId then
        print("^3Kullanım: 465ac_unban <Ban-ID>^0")
        return
    end
    local removed = BanSystem.RemoveBan(targetId)
    print(removed and ("^2[465 AC] %s ID'li ban kaydı kaldırıldı.^0"):format(targetId) or ("^1[465 AC] %s ID'li ban bulunamadı.^0"):format(targetId))
end
RegisterCommand("465ac_unban", handleUnbanCmd, false)
RegisterCommand("onlyac_unban", handleUnbanCmd, false)

local function handleTempbanCmd(source, args)
    if source ~= 0 and (not ONLY_AC or not ONLY_AC.IsBypass(source)) then
        print("^1[465 AC] Bu komutu kullanma yetkiniz yok.^0")
        return
    end
    local target = tonumber(args[1])
    local hours = tonumber(args[2])
    if not target or not hours or hours <= 0 or not GetPlayerName(target) then
        local msg = "Kullanım: /465ac_tempban <oyuncu_id> <sure_saat> <sebep>"
        if source == 0 then print(msg) else TriggerClientEvent("chat:addMessage", source, { color = {255, 255, 0}, args = {"465 AC", msg} }) end
        return
    end
    table.remove(args, 1)
    table.remove(args, 1)
    local reason = table.concat(args, " ")
    if reason == "" then reason = "Yetkili tarafından süreli yasaklama" end
    local adminName = (source == 0) and "Konsol" or GetPlayerName(source)
    BanSystem.AddBan(target, reason, hours * 3600, adminName)
    print(("^2[465 AC]^0 %s (ID %s) %s saat yasaklandı. Sebep: %s"):format(GetPlayerName(target) or "Bilinmeyen", target, hours, reason))
end
RegisterCommand("465ac_tempban", handleTempbanCmd, false)
RegisterCommand("onlyac_tempban", handleTempbanCmd, false)

CreateThread(loadBans)

exports("BanPlayer", function(src, reason, duration, bannedBy) return BanSystem.AddBan(src, reason, duration, bannedBy) end)
exports("GetBans", function() return bans end)
exports("RemoveBan", function(banId) return BanSystem.RemoveBan(banId) end)

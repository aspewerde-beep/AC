-- =========================================================================
-- 465 AC v4.2.0 - OYUNCU İSTİHBARAT, LOOKUP & TEHDİT ANALİZİ
-- Yan Hesap Korelasyonu, HWID/Lisans İlişkilendirme & Risk Puanlama
-- =========================================================================

Intelligence = {}
local historyFile = "player_history.json"
local playerHistory = {}
local dirtyHistory = false

local function loadHistory()
    local content = LoadResourceFile(GetCurrentResourceName(), historyFile)
    if content and content ~= "" then
        local success, decoded = pcall(json.decode, content)
        if success and type(decoded) == "table" then
            playerHistory = decoded
            return
        end
    end
    playerHistory = {}
    SaveResourceFile(GetCurrentResourceName(), historyFile, json.encode(playerHistory, { indent = true }), -1)
end

local function flushHistory()
    if not dirtyHistory then return end
    dirtyHistory = false
    SaveResourceFile(GetCurrentResourceName(), historyFile, json.encode(playerHistory, { indent = true }), -1)
end

local function markDirty()
    dirtyHistory = true
end

CreateThread(function()
    loadHistory()
    while true do
        Wait(15000)
        flushHistory()
    end
end)

AddEventHandler("onResourceStop", function(res)
    if res == GetCurrentResourceName() then
        flushHistory()
    end
end)

function Intelligence.MarkBanned(license, isBanned)
    if not license or license == "N/A" then return end
    if not playerHistory[license] then
        playerHistory[license] = {
            firstSeen = os.date("%Y-%m-%d %H:%M:%S"),
            lastSeen = os.date("%Y-%m-%d %H:%M:%S"),
            identifiers = { license = license },
            scanNotes = {}
        }
    end
    playerHistory[license].banned = isBanned and true or false
    markDirty()
end

function Intelligence.FindCorrelatedAccounts(identifiers)
    local matches = {}
    if not identifiers then return matches end

    local tokenSet = {}
    if type(identifiers.tokens) == "table" then
        for _, t in ipairs(identifiers.tokens) do tokenSet[t] = true end
    end

    for license, profile in pairs(playerHistory) do
        if license ~= identifiers.license and profile.identifiers then
            local matchedBy = {}

            if identifiers.ip and identifiers.ip ~= "N/A" and profile.identifiers.ip == identifiers.ip then
                table.insert(matchedBy, "IP (" .. identifiers.ip .. ")")
            end
            if identifiers.discord and identifiers.discord ~= "N/A" and profile.identifiers.discord == identifiers.discord then
                table.insert(matchedBy, "Discord (" .. identifiers.discord .. ")")
            end
            if identifiers.steam and identifiers.steam ~= "N/A" and profile.identifiers.steam == identifiers.steam then
                table.insert(matchedBy, "Steam (" .. identifiers.steam .. ")")
            end
            if identifiers.license2 and identifiers.license2 ~= "N/A" and profile.identifiers.license2 == identifiers.license2 then
                table.insert(matchedBy, "License2")
            end
            if type(profile.identifiers.tokens) == "table" and next(tokenSet) ~= nil then
                for _, pt in ipairs(profile.identifiers.tokens) do
                    if tokenSet[pt] then
                        table.insert(matchedBy, "HWID Token")
                        break
                    end
                end
            end

            if #matchedBy > 0 then
                table.insert(matches, {
                    name = profile.name or "Bilinmeyen",
                    license = license,
                    lastSeen = profile.lastSeen or "Bilinmiyor",
                    matchedBy = table.concat(matchedBy, ", "),
                    wasBanned = profile.banned or false
                })
            end
        end
    end
    return matches
end

function Intelligence.CalculateRiskScore(src, identifiers)
    local score = 0
    local factors = {}

    if identifiers.steam == "N/A" then
        score = score + 20
        table.insert(factors, "Steam hesabı bağlı değil (+20)")
    end
    if identifiers.discord == "N/A" then
        score = score + 25
        table.insert(factors, "Discord hesabı bağlı değil (+25)")
    end

    local ping = (src and GetPlayerPing(src)) or 0
    if ping > 450 then
        score = score + 15
        table.insert(factors, "Aşırı yüksek ping / ağ anomalisi (+15)")
    end

    local altAccounts = Intelligence.FindCorrelatedAccounts(identifiers)
    if #altAccounts > 0 then
        score = score + (#altAccounts * 15)
        table.insert(factors, ("%s adet ilişkili yan hesap bulundu (+%s)"):format(#altAccounts, #altAccounts * 15))
        for _, alt in ipairs(altAccounts) do
            if alt.wasBanned then
                score = score + 50
                table.insert(factors, ("Yasaklı yan hesap eşleşmesi: %s (+50 - Ban Evasion!)"):format(alt.name))
                break
            end
        end
    end

    if score > 100 then score = 100 end
    return score, factors, altAccounts
end

function Intelligence.RecordPlayer(src, ids)
    ids = ids or BanSystem.GetIdentifiers(src)
    if not ids.license or ids.license == "N/A" then return end

    local existing = playerHistory[ids.license] or {
        firstSeen = os.date("%Y-%m-%d %H:%M:%S"),
        scanNotes = {}
    }

    existing.name = GetPlayerName(src) or existing.name or "Bilinmeyen"
    existing.identifiers = ids
    existing.lastSeen = os.date("%Y-%m-%d %H:%M:%S")
    playerHistory[ids.license] = existing
    markDirty()
    return existing
end

-- BanSystem playerConnecting akışından tek deferrals üzerinde çağrılır (yarış durumu önlenir)
function Intelligence.EvaluateConnection(src, ids)
    if not ids or not ids.license or ids.license == "N/A" then
        return false, nil
    end

    Intelligence.RecordPlayer(src, ids)
    local riskScore, factors, altAccounts = Intelligence.CalculateRiskScore(src, ids)
    if AC465 then
        AC465.ThreatScores = AC465.ThreatScores or {}
        AC465.ThreatScores[src] = { score = riskScore, factors = factors }
    end

    if Config.ThreatScoring and Config.ThreatScoring.AutoBanAltAccounts then
        for _, alt in ipairs(altAccounts) do
            if alt.wasBanned then
                return true, ("\n[465 AC GÜVENLİK]\nYasaklanmış bir yan hesabınız (%s) tespit edildi.\nBan Evasion (Yasak Aşma) sebebiyle sunucuya girişiniz engellendi."):format(alt.name)
            end
        end
    end

    if Config.ThreatScoring and Config.ThreatScoring.Enabled and riskScore >= (Config.ThreatScoring.MinThreatAlertScore or 45) then
        if AC465 and AC465.SendDiscordLog then
            local factorStr = table.concat(factors, "\n- ")
            AC465.SendDiscordLog(src, "Yüksek Riskli Oyuncu Girişi (Tehdit Analizi)", ("Risk Puanı: %s / 100\n\nNedenler:\n- %s"):format(riskScore, factorStr), "log", nil)
        end
    end

    return false, nil
end

function Intelligence.Lookup(query)
    query = tostring(query or ""):lower()
    local results = {}

    for license, profile in pairs(playerHistory) do
        local match = (query == "")
        if not match and license:lower():find(query, 1, true) then match = true
        elseif not match and profile.name and profile.name:lower():find(query, 1, true) then match = true
        elseif not match and profile.identifiers then
            for _, val in pairs(profile.identifiers) do
                if type(val) ~= "table" and tostring(val):lower():find(query, 1, true) then
                    match = true
                    break
                end
            end
        end

        if match then
            local altAccounts = Intelligence.FindCorrelatedAccounts(profile.identifiers)
            table.insert(results, {
                license = license,
                name = profile.name,
                identifiers = profile.identifiers,
                firstSeen = profile.firstSeen,
                lastSeen = profile.lastSeen,
                banned = profile.banned or false,
                scanNotes = profile.scanNotes or {},
                altAccounts = altAccounts
            })
            if #results >= 30 then break end
        end
    end

    return results
end

function Intelligence.AddScanNote(license, note, status, adminName)
    if not playerHistory[license] then return false end
    if not playerHistory[license].scanNotes then
        playerHistory[license].scanNotes = {}
    end

    table.insert(playerHistory[license].scanNotes, 1, {
        date = os.date("%Y-%m-%d %H:%M:%S"),
        admin = adminName or "Sistem",
        status = status or "CLEAN",
        note = note or "Açıklama girilmedi"
    })
    markDirty()
    flushHistory()
    return true
end

local function handleLookupCmd(src, args)
    if src ~= 0 and (not AC465 or not AC465.IsBypass(src)) then
        TriggerClientEvent("chat:addMessage", src, { color = {255, 0, 0}, args = {"465 AC", "Bu komutu kullanma yetkiniz yok!"} })
        return
    end
    local query = args[1]
    if not query then
        local msg = "Kullanım: /465ac_lookup <ID | Discord_ID | License | İsim>"
        if src == 0 then print(msg) else TriggerClientEvent("chat:addMessage", src, { color = {255, 255, 0}, args = {"465 AC", msg} }) end
        return
    end
    local targetSrc = tonumber(query)
    if targetSrc and GetPlayerName(targetSrc) then
        query = BanSystem.GetIdentifiers(targetSrc).license
    end

    local results = Intelligence.Lookup(query)
    if #results == 0 then
        local msg = ("[465 AC Lookup] '%s' için kayıt bulunamadı."):format(query)
        if src == 0 then print(msg) else TriggerClientEvent("chat:addMessage", src, { color = {255, 100, 100}, args = {"465 AC", msg} }) end
        return
    end

    local p = results[1]
    local altStr = #p.altAccounts > 0 and ("%s adet (%s)"):format(#p.altAccounts, p.altAccounts[1].matchedBy) or "Yok"
    local scanStr = #p.scanNotes > 0 and ("%s (%s)"):format(p.scanNotes[1].status, p.scanNotes[1].note) or "Yok"
    local out = ("\n[465 AC İSTİHBARAT RAPORU]\nİsim: %s | Banlı: %s\nLisans: %s\nDiscord: %s | Steam: %s\nİlk: %s | Son: %s\nYan Hesaplar: %s\nTarama Notu: %s"):format(
        p.name, tostring(p.banned), p.license, p.identifiers.discord or "N/A", p.identifiers.steam or "N/A", p.firstSeen or "N/A", p.lastSeen or "N/A", altStr, scanStr
    )
    if src == 0 then print(out) else TriggerClientEvent("chat:addMessage", src, { color = {0, 220, 255}, args = {"465 AC", out} }) end
end
RegisterCommand("465ac_lookup", handleLookupCmd, false)

local function handleScanCmd(src, args)
    if src ~= 0 and (not AC465 or not AC465.IsBypass(src)) then
        TriggerClientEvent("chat:addMessage", src, { color = {255, 0, 0}, args = {"465 AC", "Bu komutu kullanma yetkiniz yok!"} })
        return
    end
    local target = tonumber(args[1])
    local status = args[2] and args[2]:upper()
    if not target or not GetPlayerName(target) or (status ~= "CLEAN" and status ~= "DETECTED" and status ~= "SUSPICIOUS") then
        local msg = "Kullanım: /465ac_scan <Oyuncu_ID> <CLEAN | DETECTED | SUSPICIOUS> <Not>"
        if src == 0 then print(msg) else TriggerClientEvent("chat:addMessage", src, { color = {255, 255, 0}, args = {"465 AC", msg} }) end
        return
    end
    table.remove(args, 1)
    table.remove(args, 1)
    local note = table.concat(args, " ")
    if note == "" then note = "Manuel tarama kaydı" end

    local ids = BanSystem.GetIdentifiers(target)
    local adminName = src == 0 and "Konsol" or (GetPlayerName(src) or "Yetkili")
    if Intelligence.AddScanNote(ids.license, note, status, adminName) then
        local msg = ("[465 AC Scan] %s (ID %s) için '%s' notu kaydedildi."):format(GetPlayerName(target), target, status)
        if src == 0 then print(msg) else TriggerClientEvent("chat:addMessage", src, { color = {0, 255, 128}, args = {"465 AC", msg} }) end
        AC465.SendDiscordLog(target, "Harici Tarama Sonucu İşlendi", ("Yetkili: %s\nDurum: **%s**\nNot: %s"):format(adminName, status, note), "log", nil)
    end
end
RegisterCommand("465ac_scan", handleScanCmd, false)

exports("LookupPlayer", function(query) return Intelligence.Lookup(query) end)

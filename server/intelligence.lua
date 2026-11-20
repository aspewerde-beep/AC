-- =========================================================================
-- ONLY AC v4.2.0 - OYUNCU İSTİHBARAT, LOOKUP VE TEHDİT ANALİZİ (INTELLIGENCE)
-- Standartlar: Ocean Scanner, SecuroX & FeloxAC v4.1 Intelligence Ekosistemi
-- =========================================================================

Intelligence = {}
local historyFile = "player_history.json"
local playerHistory = {}

-- Geçmiş verilerini dosyadan yükle
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

-- Geçmiş verilerini kaydet
local function saveHistory()
    SaveResourceFile(GetCurrentResourceName(), historyFile, json.encode(playerHistory, { indent = true }), -1)
end

CreateThread(function()
    loadHistory()
end)

-- 1. YAN HESAP (ALT ACCOUNT) TESPİTİ VE İLİŞKİLENDİRME
-- Bir oyuncunun kullandığı IP, Discord veya Steam ID daha önce başka bir lisansla kullanılmış mı?
function Intelligence.FindCorrelatedAccounts(identifiers)
    local matches = {}
    for license, profile in pairs(playerHistory) do
        if license ~= identifiers.license then
            local isMatch = false
            local matchedBy = {}

            -- IP eşleşmesi
            if identifiers.ip ~= "N/A" and profile.identifiers.ip == identifiers.ip then
                isMatch = true
                table.insert(matchedBy, "IP (" .. identifiers.ip .. ")")
            end
            -- Discord eşleşmesi
            if identifiers.discord ~= "N/A" and profile.identifiers.discord == identifiers.discord then
                isMatch = true
                table.insert(matchedBy, "Discord (" .. identifiers.discord .. ")")
            end
            -- Steam eşleşmesi
            if identifiers.steam ~= "N/A" and profile.identifiers.steam == identifiers.steam then
                isMatch = true
                table.insert(matchedBy, "Steam (" .. identifiers.steam .. ")")
            end

            if isMatch then
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

-- 2. TEHDİT VE RİSK PUANI HESAPLAMA (THREAT RISK SCORING 0-100)
-- Ocean & SecuroX Analiz Standartları
function Intelligence.CalculateRiskScore(src, identifiers)
    local score = 0
    local factors = {}

    -- Steam bağlı değilse
    if identifiers.steam == "N/A" then
        score = score + 20
        table.insert(factors, "Steam hesabı bağlı değil (+20)")
    end

    -- Discord bağlı değilse
    if identifiers.discord == "N/A" then
        score = score + 25
        table.insert(factors, "Discord hesabı bağlı değil (+25)")
    end

    -- Ping anormalliği (500ms üzeri aşırı lag / spoofer)
    local ping = GetPlayerPing(src) or 0
    if ping > 450 then
        score = score + 15
        table.insert(factors, "Aşırı yüksek ping / şüpheli ağ bağlantısı (+15)")
    end

    -- İlişkili yan hesapların incelenmesi
    local altAccounts = Intelligence.FindCorrelatedAccounts(identifiers)
    if #altAccounts > 0 then
        score = score + (#altAccounts * 15)
        table.insert(factors, ("%s adet ilişkili yan hesap bulundu (+%s)"):format(#altAccounts, #altAccounts * 15))

        -- Eğer ilişkili hesaplardan biri daha önce BAN YEMİŞSE (Ban Evasion / Kaçma)
        for _, alt in ipairs(altAccounts) do
            if alt.wasBanned then
                score = score + 50
                table.insert(factors, ("Yasaklanmış bir yan hesapla eşleşti: %s (+50 - Ban Evasion!)"):format(alt.name))
                break
            end
        end
    end

    -- Maksimum 100 ile sınırla
    if score > 100 then score = 100 end

    return score, factors, altAccounts
end

-- 3. OYUNCU BAĞLANTISINI KAYDET VE GÜNCELLE
function Intelligence.RecordPlayer(src)
    local ids = BanSystem.GetIdentifiers(src)
    if not ids.license or ids.license == "N/A" then return end

    local name = GetPlayerName(src) or "Bilinmeyen"
    local existing = playerHistory[ids.license] or {
        firstSeen = os.date("%Y-%m-%d %H:%M:%S"),
        scanNotes = {}
    }

    existing.name = name
    existing.identifiers = ids
    existing.lastSeen = os.date("%Y-%m-%d %H:%M:%S")

    playerHistory[ids.license] = existing
    saveHistory()

    return existing
end

-- 4. OYUNCU LİSTESİNDE SORGULAMA (LOOKUP ENGINE)
function Intelligence.Lookup(query)
    query = tostring(query):lower()
    local results = {}

    for license, profile in pairs(playerHistory) do
        local match = false

        if license:lower():find(query, 1, true) then match = true
        elseif profile.name and profile.name:lower():find(query, 1, true) then match = true
        elseif profile.identifiers then
            for _, val in pairs(profile.identifiers) do
                if tostring(val):lower():find(query, 1, true) then
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
        end
    end

    return results
end

-- 5. HARİCİ TARAMA (OCEAN / SS) SONUCU VE NOT EKLEME
function Intelligence.AddScanNote(license, note, status, adminName)
    if not playerHistory[license] then return false end
    if not playerHistory[license].scanNotes then
        playerHistory[license].scanNotes = {}
    end

    table.insert(playerHistory[license].scanNotes, 1, {
        date = os.date("%Y-%m-%d %H:%M:%S"),
        admin = adminName or "Sistem",
        status = status or "CLEAN", -- CLEAN, DETECTED, SUSPICIOUS
        note = note or "Açıklama girilmedi"
    })

    saveHistory()
    return true
end

-- 6. OYUNCU GİRİŞİNDE TEHDİT KONTROLÜ (playerConnecting Event Hook)
AddEventHandler("playerConnecting", function(name, setKickReason, deferrals)
    local src = source
    local ids = BanSystem.GetIdentifiers(src)
    if not ids.license or ids.license == "N/A" then return end

    -- Profil kaydet
    Intelligence.RecordPlayer(src)

    -- Risk Skoru Hesapla
    local riskScore, factors, altAccounts = Intelligence.CalculateRiskScore(src, ids)

    -- Eğer ban yemiş bir yan hesap ile eşleştiyse ve Otomatik Ban aktifse
    if Config.ThreatScoring and Config.ThreatScoring.AutoBanAltAccounts then
        for _, alt in ipairs(altAccounts) do
            if alt.wasBanned then
                deferrals.done(("\n[ONLY AC GÜVENLİK]\nYasaklanmış bir yan hesabınız (%s) tespit edildi.\nBan Evasion (Yasak Aşma) sebebiyle sunucuya girişiniz engellendi."):format(alt.name))
                return
            end
        end
    end

    -- Yüksek riskli oyuncu Discord bildirimi
    if Config.ThreatScoring and Config.ThreatScoring.Enabled and riskScore >= (Config.ThreatScoring.MinThreatAlertScore or 50) then
        local factorStr = table.concat(factors, "\n- ")
        ONLY_AC.SendDiscordLog(src, "⚠️ Yüksek Riskli Oyuncu Girişi (Tehdit Analizi)", ("Risk Puanı: %s / 100\n\nNedenler:\n- %s"):format(riskScore, factorStr), "log", nil)
    end
end)

-- =========================================================================
-- YETKİLİ KOMUTLARI: LOOKUP & SCAN
-- =========================================================================

-- /onlyac_lookup <oyuncu_id | discord_id | lisans | isim>
RegisterCommand("onlyac_lookup", function(src, args)
    if src ~= 0 and not ONLY_AC.IsBypass(src) then
        TriggerClientEvent("chat:addMessage", src, { color = {255, 0, 0}, args = {"ONLY AC", "Bu komutu kullanma yetkiniz yok!"} })
        return
    end

    local query = args[1]
    if not query then
        local msg = "Kullanım: /onlyac_lookup <ID | Discord_ID | License | İsim>"
        if src == 0 then print(msg) else TriggerClientEvent("chat:addMessage", src, { color = {255, 255, 0}, args = {"ONLY AC", msg} }) end
        return
    end

    -- Eğer canlı oyuncu ID'si girildiyse lisansını al
    local targetSrc = tonumber(query)
    if targetSrc and GetPlayerName(targetSrc) then
        local ids = BanSystem.GetIdentifiers(targetSrc)
        query = ids.license
    end

    local results = Intelligence.Lookup(query)
    if #results == 0 then
        local msg = ("[ONLY AC Lookup] '%s' için kayıt bulunamadı."):format(query)
        if src == 0 then print(msg) else TriggerClientEvent("chat:addMessage", src, { color = {255, 100, 100}, args = {"ONLY AC", msg} }) end
        return
    end

    local profile = results[1]
    local altStr = #profile.altAccounts > 0 and ("%s adet (%s)"):format(#profile.altAccounts, profile.altAccounts[1].matchedBy) or "Yok"
    local scanStr = #profile.scanNotes > 0 and ("%s (Son: %s)"):format(profile.scanNotes[1].status, profile.scanNotes[1].note) or "Kayıtlı tarama yok"

    local output = ("\n================ [ OYUNCU İSTİHBARAT RAPORU ] ================\nİsim: %s\nLisans: %s\nDiscord: %s\nSteam: %s\nİlk Giriş: %s | Son Giriş: %s\nİlişkili Yan Hesaplar: %s\nHarici SS / Ocean Durumu: %s\n============================================================="):format(
        profile.name,
        profile.license,
        profile.identifiers.discord or "N/A",
        profile.identifiers.steam or "N/A",
        profile.firstSeen or "N/A",
        profile.lastSeen or "N/A",
        altStr,
        scanStr
    )

    if src == 0 then
        print(output)
    else
        TriggerClientEvent("chat:addMessage", src, { color = {0, 220, 255}, args = {"ONLY AC", output} })
    end
end, false)

-- /onlyac_scan <id> <CLEAN|DETECTED|SUSPICIOUS> <Açıklama/Not>
RegisterCommand("onlyac_scan", function(src, args)
    if src ~= 0 and not ONLY_AC.IsBypass(src) then
        TriggerClientEvent("chat:addMessage", src, { color = {255, 0, 0}, args = {"ONLY AC", "Bu komutu kullanma yetkiniz yok!"} })
        return
    end

    local target = tonumber(args[1])
    local status = args[2] and args[2]:upper()
    if not target or not GetPlayerName(target) or (status ~= "CLEAN" and status ~= "DETECTED" and status ~= "SUSPICIOUS") then
        local msg = "Kullanım: /onlyac_scan <Oyuncu_ID> <CLEAN | DETECTED | SUSPICIOUS> <Tarama Notu / Ocean Linki>"
        if src == 0 then print(msg) else TriggerClientEvent("chat:addMessage", src, { color = {255, 255, 0}, args = {"ONLY AC", msg} }) end
        return
    end

    table.remove(args, 1)
    table.remove(args, 1)
    local note = table.concat(args, " ")
    if note == "" then note = "Ocean / SS Taraması yapıldı" end

    local ids = BanSystem.GetIdentifiers(target)
    local adminName = src == 0 and "Konsol" or (GetPlayerName(src) or "Yetkili")
    local success = Intelligence.AddScanNote(ids.license, note, status, adminName)

    if success then
        local msg = ("[ONLY AC Scan] %s (ID %s) için tarama sonucu '%s' olarak kaydedildi."):format(GetPlayerName(target), target, status)
        if src == 0 then print(msg) else TriggerClientEvent("chat:addMessage", src, { color = {0, 255, 128}, args = {"ONLY AC", msg} }) end
        ONLY_AC.SendDiscordLog(target, "📋 Harici Tarama Sonucu İşlendi", ("Yetkili: %s\nDurum: **%s**\nNot: %s"):format(adminName, status, note), "log", nil)
    end
end, false)

-- Exports
exports("LookupPlayer", function(query) return Intelligence.Lookup(query) end)
exports("AddScanNote", function(license, note, status, admin) return Intelligence.AddScanNote(license, note, status, admin) end)
exports("GetPlayerHistory", function() return playerHistory end)

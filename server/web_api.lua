-- =========================================================================
-- 465 AC v4.2.0 - GÖMÜLÜ WEB YÖNETİM PANELİ VE REST API
-- =========================================================================

local authTokens = {}
local ipRateLimits = {}
local failedLogins = {}

-- Web panel ayarları
Config.WebPanelEnabled = (Config.WebPanelEnabled == nil) and true or Config.WebPanelEnabled
Config.WebPanelPassword = Config.WebPanelPassword or "465ac_admin"

-- Süresi geçmiş tokenları temizle
local function cleanExpiredTokens()
    local now = os.time()
    for token, exp in pairs(authTokens) do
        if exp <= now then
            authTokens[token] = nil
        end
    end
end

-- 12 saat geçerli auth token üret
local function generateAuthToken()
    cleanExpiredTokens()
    local token = "OAC-AUTH-" .. tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999))
    authTokens[token] = os.time() + 43200 -- 12 saat geçerli
    return token
end

-- Yetki kontrolü (Bearer veya doğrudan token desteği)
local function isAuthorized(req)
    cleanExpiredTokens()
    local token = req.headers and (req.headers["authorization"] or req.headers["Authorization"])
    if token then
        token = token:gsub("^Bearer%s+", "")
        if authTokens[token] and authTokens[token] > os.time() then
            return true
        end
    end
    return false
end

-- İstemci IP adresi tespiti
local function getClientIP(req)
    if not req then return "unknown" end
    local forwarded = req.headers and (req.headers["x-forwarded-for"] or req.headers["X-Forwarded-For"])
    if forwarded and forwarded ~= "" then
        local first = forwarded:match("([^,]+)")
        if first then return first:gsub("%s+", "") end
    end
    return req.address or "unknown"
end

-- Rate Limit kontrolü (Dakikada maksimum 60 istek)
local function checkRateLimit(ip)
    local now = os.time()
    local record = ipRateLimits[ip]
    if not record or now > record.resetTime then
        ipRateLimits[ip] = { count = 1, resetTime = now + 60 }
        return true
    end
    record.count = record.count + 1
    if record.count > 60 then
        return false
    end
    return true
end

-- Brute-Force giriş kilidi kontrolü (5 hatalı denemede 5 dakika kilit)
local function isIpLocked(ip)
    local record = failedLogins[ip]
    if record and record.lockedUntil and record.lockedUntil > os.time() then
        return true, record.lockedUntil - os.time()
    end
    return false, 0
end

local function recordFailedLogin(ip)
    local now = os.time()
    local record = failedLogins[ip] or { count = 0, lockedUntil = 0 }
    record.count = record.count + 1
    if record.count >= 5 then
        record.lockedUntil = now + 300 -- 5 dakika kilit
    end
    failedLogins[ip] = record
end

local function resetFailedLogin(ip)
    failedLogins[ip] = nil
end

-- Ortak CORS & JSON Yanıt Yardımcısı
local function sendResponse(res, status, data, extraHeaders)
    local headers = {
        ["Content-Type"] = "application/json; charset=utf-8",
        ["Access-Control-Allow-Origin"] = "*",
        ["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS, PUT, DELETE",
        ["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With, X-Lookup-Query"
    }
    if extraHeaders then
        for k, v in pairs(extraHeaders) do headers[k] = v end
    end
    res.writeHead(status, headers)
    if type(data) == "table" then
        res.send(json.encode(data))
    else
        res.send(data or "")
    end
end

-- FiveM HTTP İstek Dinleyicisi
SetHttpHandler(function(req, res)
    local rawPath = req.path or "/"
    local path = rawPath:match("^([^?]+)") or rawPath
    local method = req.method or "GET"
    local clientIp = getClientIP(req)

    -- 0. CORS Preflight İsteği
    if method == "OPTIONS" then
        res.writeHead(200, {
            ["Access-Control-Allow-Origin"] = "*",
            ["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS, PUT, DELETE",
            ["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With, X-Lookup-Query"
        })
        res.send("")
        return
    end

    -- 1. Statik Web Sayfası: GET / veya GET /index.html
    if method == "GET" and (path == "/" or path == "/index.html" or path == "" or path == "/web/index.html") then
        local html = LoadResourceFile(GetCurrentResourceName(), "web/index.html")
        if html then
            res.writeHead(200, {
                ["Content-Type"] = "text/html; charset=utf-8",
                ["Access-Control-Allow-Origin"] = "*"
            })
            res.send(html)
        else
            res.writeHead(404, { ["Content-Type"] = "text/plain; charset=utf-8" })
            res.send("Web panel dosyasi bulunamadi (web/index.html).")
        end
        return
    end

    -- API İstekleri için Rate Limit Kontrolü
    if not checkRateLimit(clientIp) then
        sendResponse(res, 429, {
            error = "too_many_requests",
            message = "Cok fazla istek gonderdiniz. Dakikada maksimum 60 istek hakkınız bulunmaktadır."
        })
        return
    end

    -- 2. Giriş Doğrulama: POST /api/auth
    if method == "POST" and path == "/api/auth" then
        local locked, remaining = isIpLocked(clientIp)
        if locked then
            sendResponse(res, 403, {
                success = false,
                message = ("Cok fazla basarisiz deneme. Guvenliginiz icin IP adresiniz %d saniye boyunca kilitlendi."):format(remaining)
            })
            return
        end

        req.setDataHandler(function(body)
            local ok, data = pcall(json.decode, body or "{}")
            if not ok or type(data) ~= "table" then
                sendResponse(res, 400, { success = false, message = "Gecersiz JSON verisi" })
                return
            end

            local expected = Config.WebPanelPassword or "465ac_admin"
            if data.password and tostring(data.password) == tostring(expected) then
                resetFailedLogin(clientIp)
                local token = generateAuthToken()
                sendResponse(res, 200, { success = true, token = token })
            else
                recordFailedLogin(clientIp)
                sendResponse(res, 401, { success = false, message = "Gecersiz sifre" })
            end
        end)
        return
    end

    -- 3. Durum & Bilgi Alma: GET /api/status
    if method == "GET" and path == "/api/status" then
        if not isAuthorized(req) then
            sendResponse(res, 401, { error = "unauthorized", message = "Yetkisiz erisim" })
            return
        end

        local function buildSafeStatusConfig()
            local safe = {}
            for k, v in pairs(Config or {}) do
                if k == "WebPanelPassword" then
                    safe[k] = nil
                elseif k == "DiscordWebhook" then
                    if type(v) == "string" and #v > 8 then
                        safe.DiscordWebhook = "__MASKED__" .. v:sub(-6)
                        safe.HasDiscordWebhook = true
                    elseif type(v) == "string" and v ~= "" then
                        safe.DiscordWebhook = "__MASKED__"
                        safe.HasDiscordWebhook = true
                    else
                        safe.DiscordWebhook = ""
                        safe.HasDiscordWebhook = false
                    end
                else
                    safe[k] = v
                end
            end
            return safe
        end

        local bans = BanSystem.GetBans and BanSystem.GetBans() or {}
        local stats = ONLY_AC.Stats or { totalDetections = 0, totalBans = 0, totalKicks = 0, startTime = os.time() }
        local statusData = {
            serverName = Config.ServerName or "465 AC",
            version = Config.Version or "4.2.0",
            config = buildSafeStatusConfig(),
            bans = bans,
            recentLogs = ONLY_AC.RecentLogs or {},
            playerCount = #GetPlayers(),
            stats = {
                totalDetections = stats.totalDetections or 0,
                totalBans = stats.totalBans or 0,
                totalKicks = stats.totalKicks or 0,
                uptime = os.time() - (stats.startTime or os.time())
            }
        }
        sendResponse(res, 200, statusData)
        return
    end

    -- 4. İstatistik Bilgisi: GET /api/stats
    if method == "GET" and path == "/api/stats" then
        if not isAuthorized(req) then
            sendResponse(res, 401, { error = "unauthorized", message = "Yetkisiz erisim" })
            return
        end

        local stats = ONLY_AC.Stats or { totalDetections = 0, totalBans = 0, totalKicks = 0, startTime = os.time() }
        local statsData = {
            totalDetections = stats.totalDetections or 0,
            totalBans = stats.totalBans or 0,
            totalKicks = stats.totalKicks or 0,
            uptime = os.time() - (stats.startTime or os.time()),
            playerCount = #GetPlayers(),
            serverName = Config.ServerName or "465 AC"
        }
        sendResponse(res, 200, statsData)
        return
    end

    -- 5. Aktif Oyuncu Listesi: GET /api/players
    if method == "GET" and path == "/api/players" then
        if not isAuthorized(req) then
            sendResponse(res, 401, { error = "unauthorized", message = "Yetkisiz erisim" })
            return
        end

        local playerList = {}
        for _, pId in ipairs(GetPlayers()) do
            local src = tonumber(pId)
            if src then
                local ids = BanSystem.GetIdentifiers and BanSystem.GetIdentifiers(src) or {}
                table.insert(playerList, {
                    id = src,
                    name = GetPlayerName(src) or "Bilinmeyen",
                    ping = GetPlayerPing(src) or 0,
                    bypass = (ONLY_AC.IsBypassed and ONLY_AC.IsBypassed(src)) or false,
                    threat = (ONLY_AC.ThreatScores and ONLY_AC.ThreatScores[src] and ONLY_AC.ThreatScores[src].score) or 0,
                    identifiers = ids
                })
            end
        end
        sendResponse(res, 200, { players = playerList, count = #playerList })
        return
    end

    -- 6. Oyuncu Atma: POST /api/kick
    if method == "POST" and path == "/api/kick" then
        if not isAuthorized(req) then
            sendResponse(res, 401, { error = "unauthorized", message = "Yetkisiz erisim" })
            return
        end

        req.setDataHandler(function(body)
            local ok, data = pcall(json.decode, body or "{}")
            if not ok or type(data) ~= "table" or not data.playerId then
                sendResponse(res, 400, { success = false, message = "Gecersiz istek veya playerId eksik" })
                return
            end

            local target = tonumber(data.playerId)
            if target and GetPlayerName(target) then
                local reason = data.reason or "Yetkili tarafindan web panelden atildiniz."
                DropPlayer(target, ("\n[465 AC] Sunucudan Atildiniz!\nSebep: %s"):format(reason))
                if ONLY_AC.Stats then
                    ONLY_AC.Stats.totalKicks = (ONLY_AC.Stats.totalKicks or 0) + 1
                end
                sendResponse(res, 200, { success = true, message = ("ID %s basariyla sunucudan atildi."):format(target) })
            else
                sendResponse(res, 404, { success = false, message = "Oyuncu bulunamadi veya aktif degil." })
            end
        end)
        return
    end

    -- 7. Oyuncu Yasaklama: POST /api/ban
    if method == "POST" and path == "/api/ban" then
        if not isAuthorized(req) then
            sendResponse(res, 401, { error = "unauthorized", message = "Yetkisiz erisim" })
            return
        end

        req.setDataHandler(function(body)
            local ok, data = pcall(json.decode, body or "{}")
            if not ok or type(data) ~= "table" or not data.playerId then
                sendResponse(res, 400, { success = false, message = "Gecersiz istek veya playerId eksik" })
                return
            end

            local target = tonumber(data.playerId)
            if target and GetPlayerName(target) then
                local reason = data.reason or "Web Paneli uzerinden yasaklama"
                local duration = tonumber(data.duration)
                if duration and duration <= 0 then duration = nil end
                local banRecord = BanSystem.AddBan(target, reason, duration, "Web Panel")
                if ONLY_AC.Stats then
                    ONLY_AC.Stats.totalBans = (ONLY_AC.Stats.totalBans or 0) + 1
                end
                sendResponse(res, 200, { success = true, ban = banRecord })
            else
                sendResponse(res, 404, { success = false, message = "Oyuncu bulunamadi veya aktif degil." })
            end
        end)
        return
    end

    -- 8. Ayarları Kaydetme: POST /api/config
    if method == "POST" and path == "/api/config" then
        if not isAuthorized(req) then
            sendResponse(res, 401, { error = "unauthorized", message = "Yetkisiz erisim" })
            return
        end

        req.setDataHandler(function(body)
            local ok, data = pcall(json.decode, body or "{}")
            if not ok or type(data) ~= "table" or not data.config or type(data.config) ~= "table" then
                sendResponse(res, 400, { success = false, message = "Gecersiz veri formati" })
                return
            end

            local editableScalar = {
                ServerName = "string",
                DefaultAction = "string",
                AcePermission = "string",
                ScreenCaptureEnabled = "boolean",
                ScreenshotQuality = "number",
                ScreenshotCaptureTimeoutMs = "number",
                SpawningGracePeriodSeconds = "number",
                ViolationStrikes = "number",
                Debug = "boolean",
                BanDiscordLogs = "boolean",
                SendToAllLogs = "boolean",
                MaxFootSpeed = "number",
                MaxVehicleSpeedKMH = "number",
                MaxVehicleSpeedModifier = "number",
                MaxTeleportDistance = "number",
                MaxHealth = "number",
                MaxArmor = "number",
                MaxShootDistance = "number",
                MaxWeaponDamage = "number",
                MaxHeavyWeaponDamage = "number",
                MaxMeleeDamage = "number",
                MaxPlayerZVelocity = "number",
                MaxVehicleZVelocity = "number",
                AimbotAngleThreshold = "number",
                AimbotCheckWindow = "number",
                AimbotSnapCount = "number",
                SilentAimMinDot = "number",
                StaminaCheckInterval = "number",
                MaxConsecutiveSprintSeconds = "number",
                HeartbeatInterval = "number",
                HeartbeatTimeoutSeconds = "number",
                HandshakeTimeoutSeconds = "number",
                MaxParticlePerWindow = "number",
                ParticleWindowSeconds = "number",
                MaxPedSpawnsPerWindow = "number",
                PedWindowSeconds = "number",
                MaxResourceStartsPerWindow = "number",
                ResourceWindowSeconds = "number",
                MaxEntitySpawnsPerWindow = "number",
                EntityWindowSeconds = "number",
                MaxExplosionsPerWindow = "number",
                ExplosionWindowSeconds = "number"
            }
            local validModes = { off = true, log = true, kick = true, ban = true }

            for k, v in pairs(data.config) do
                if k == "DiscordWebhook" and type(v) == "string" then
                    if v == "" then
                        Config.DiscordWebhook = ""
                    elseif not v:find("^__MASKED__") and (v:find("^https://discord%.com/api/webhooks/") or v:find("^https://discordapp%.com/api/webhooks/")) then
                        Config.DiscordWebhook = v
                    end
                elseif k == "Protections" and type(v) == "table" then
                    Config.Protections = Config.Protections or {}
                    for pKey, pVal in pairs(v) do
                        if type(pKey) == "string" then
                            if type(pVal) == "boolean" then
                                Config.Protections[pKey] = pVal
                            elseif type(pVal) == "string" and validModes[pVal:lower()] then
                                Config.Protections[pKey] = pVal:lower()
                            end
                        end
                    end
                elseif k == "ThreatScoring" and type(v) == "table" then
                    Config.ThreatScoring = Config.ThreatScoring or {}
                    local tsSchema = { Enabled = "boolean", MinThreatAlertScore = "number", AutoBanAltAccounts = "boolean" }
                    for tKey, tVal in pairs(v) do
                        if tsSchema[tKey] and type(tVal) == tsSchema[tKey] then
                            Config.ThreatScoring[tKey] = tVal
                        end
                    end
                elseif k == "EventTriggerGuard" and type(v) == "table" then
                    Config.EventTriggerGuard = Config.EventTriggerGuard or {}
                    for eKey, eVal in pairs(v) do
                        if (eKey == "Enabled" and type(eVal) == "boolean")
                            or (eKey == "MaxTriggersPerSecond" and type(eVal) == "number") then
                            Config.EventTriggerGuard[eKey] = eVal
                        end
                    end
                elseif editableScalar[k] and type(v) == editableScalar[k] then
                    if k == "DefaultAction" then
                        local norm = v:lower()
                        if norm == "log" or norm == "kick" or norm == "ban" then
                            Config.DefaultAction = norm
                        end
                    else
                        Config[k] = v
                    end
                end
            end

            if ONLY_AC and ONLY_AC.BroadcastProtections then
                ONLY_AC.BroadcastProtections()
            end

            -- Sadece güvenli ayarları kalıcı runtime_config.json olarak kaydet (şifre asla diske yazılmaz)
            local persist = {
                Protections = Config.Protections,
                ThreatScoring = Config.ThreatScoring,
                EventTriggerGuard = Config.EventTriggerGuard
            }
            for k, _ in pairs(editableScalar) do
                if Config[k] ~= nil then persist[k] = Config[k] end
            end
            if type(Config.DiscordWebhook) == "string" and Config.DiscordWebhook ~= "" then
                persist.DiscordWebhook = Config.DiscordWebhook
            end

            SaveResourceFile(GetCurrentResourceName(), "runtime_config.json", json.encode(persist, { indent = true }), -1)
            print("^2[465 AC Web Panel]^0 Ayarlar web paneli uzerinden guncellendi ve runtime_config.json dosyasina kaydedildi.")
            sendResponse(res, 200, { success = true, message = "Yapilandirma basariyla kaydedildi ve uygulandi." })
        end)
        return
    end

    -- 9. Ban Kaldırma: POST /api/unban
    if method == "POST" and path == "/api/unban" then
        if not isAuthorized(req) then
            sendResponse(res, 401, { error = "unauthorized", message = "Yetkisiz erisim" })
            return
        end

        req.setDataHandler(function(body)
            local ok, data = pcall(json.decode, body or "{}")
            if not ok or type(data) ~= "table" or not data.banId then
                sendResponse(res, 400, { success = false, message = "Gecersiz istek veya Ban ID eksik" })
                return
            end

            if BanSystem.RemoveBan then
                local success = BanSystem.RemoveBan(data.banId)
                sendResponse(res, 200, {
                    success = success,
                    message = success and "Ban kaydi basariyla kaldirildi." or "Ban kaydi bulunamadi."
                })
            else
                sendResponse(res, 500, { success = false, message = "Ban yonetim sistemi hazir degil." })
            end
        end)
        return
    end

    -- 10. Oyuncu İstihbarat & Lookup: GET /api/lookup
    if method == "GET" and path:find("^/api/lookup") then
        if not isAuthorized(req) then
            sendResponse(res, 401, { error = "unauthorized", message = "Yetkisiz erisim" })
            return
        end

        local query = req.headers and (req.headers["x-lookup-query"] or req.headers["X-Lookup-Query"]) or ""
        if query == "" then
            local rawPath = req and req.path or path
            local qParam = type(rawPath) == "string" and rawPath:match("[?&]q=([^&]+)") or nil
            if qParam then
                query = qParam:gsub("+", " "):gsub("%%(%x%x)", function(hex)
                    return string.char(tonumber(hex, 16))
                end)
            end
        end
        local results = (Intelligence and Intelligence.Lookup) and Intelligence.Lookup(query) or {}
        sendResponse(res, 200, { success = true, results = results, count = #results })
        return
    end

    -- 11. Harici SS / Ocean Tarama Notu Ekleme: POST /api/player/scan
    if method == "POST" and path == "/api/player/scan" then
        if not isAuthorized(req) then
            sendResponse(res, 401, { error = "unauthorized", message = "Yetkisiz erisim" })
            return
        end

        req.setDataHandler(function(body)
            local ok, data = pcall(json.decode, body or "{}")
            if not ok or type(data) ~= "table" or not data.license then
                sendResponse(res, 400, { success = false, message = "Eksik parametre (license)" })
                return
            end

            if Intelligence and Intelligence.AddScanNote then
                local success = Intelligence.AddScanNote(data.license, data.note, data.status, "Web Paneli")
                sendResponse(res, 200, { success = success, message = success and "Tarama notu basariyla kaydedildi." or "Oyuncu profili bulunamadi." })
            else
                sendResponse(res, 500, { success = false, message = "İstihbarat sistemi hazir degil." })
            end
        end)
        return
    end

    -- 12. Harita Temizleme (Clear Map): POST /api/clear
    if method == "POST" and path == "/api/clear" then
        if not isAuthorized(req) then
            sendResponse(res, 401, { error = "unauthorized", message = "Yetkisiz erisim" })
            return
        end

        req.setDataHandler(function(body)
            local ok, data = pcall(json.decode, body or "{}")
            local targetType = (ok and data.type) and data.type:lower() or "all"
            local count = 0

            if targetType == "vehicles" or targetType == "peds" or targetType == "props" or targetType == "all" then
                if ONLY_AC and ONLY_AC.ClearEntities then
                    count = ONLY_AC.ClearEntities(targetType)
                end
            else
                sendResponse(res, 400, { success = false, message = "Gecersiz temizleme turu" })
                return
            end

            sendResponse(res, 200, { success = true, cleared = count, type = targetType })
        end)
        return
    end

    -- Tanınmayan istek
    sendResponse(res, 404, { error = "not_found", message = "Bilinmeyen API endpointi." })
end)

-- Başlangıçta eğer runtime_config.json varsa güvenli alanları birleştirerek yükle
CreateThread(function()
    local runtimeData = LoadResourceFile(GetCurrentResourceName(), "runtime_config.json")
    if runtimeData and runtimeData ~= "" then
        local success, decoded = pcall(json.decode, runtimeData)
        if success and type(decoded) == "table" then
            local blockedKeys = { WebPanelPassword = true, WebPanelPort = true, Version = true, LegacyAcePermission = true }
            for k, v in pairs(decoded) do
                if not blockedKeys[k] then
                    if k == "DiscordWebhook" then
                        if type(v) == "string" and not v:find("^__MASKED__") and not v:find("^%*%*%*") then
                            Config.DiscordWebhook = v
                        end
                    elseif (k == "Protections" or k == "ThreatScoring" or k == "EventTriggerGuard") and type(v) == "table" and type(Config[k]) == "table" then
                        for subK, subV in pairs(v) do
                            Config[k][subK] = subV
                        end
                    else
                        Config[k] = v
                    end
                end
            end
            print("^2[465 AC]^0 Kaydedilmis Web Panel ayarlari (runtime_config.json) yuklendi.")
        end
    end
end)

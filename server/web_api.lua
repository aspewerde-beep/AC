-- =========================================================================
-- ONLY AC v3.0.0 (ULTIMATE EDITION) - GÖMÜLÜ WEB YÖNETİM PANELİ VE REST API
-- =========================================================================

local authTokens = {}
local ipRateLimits = {}
local failedLogins = {}

-- Web panel ayarları
Config.WebPanelEnabled = (Config.WebPanelEnabled == nil) and true or Config.WebPanelEnabled
Config.WebPanelPassword = Config.WebPanelPassword or "onlyac_admin"

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
        ["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With"
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
    local path = req.path or "/"
    local method = req.method or "GET"
    local clientIp = getClientIP(req)

    -- 0. CORS Preflight İsteği
    if method == "OPTIONS" then
        res.writeHead(200, {
            ["Access-Control-Allow-Origin"] = "*",
            ["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS, PUT, DELETE",
            ["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With"
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

            local expected = Config.WebPanelPassword or "onlyac_admin"
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

        local bans = BanSystem.GetBans and BanSystem.GetBans() or {}
        local stats = ONLY_AC.Stats or { totalDetections = 0, totalBans = 0, totalKicks = 0, startTime = os.time() }
        local statusData = {
            serverName = Config.ServerName or "ONLY AC",
            version = "3.0.0",
            config = Config,
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
            serverName = Config.ServerName or "ONLY AC"
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
                DropPlayer(target, ("\n[ONLY AC] Sunucudan Atildiniz!\nSebep: %s"):format(reason))
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
                local banRecord = BanSystem.AddBan(target, reason, duration)
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

            -- Canlı Config'i güncelle
            for k, v in pairs(data.config) do
                Config[k] = v
            end

            -- runtime_config.json olarak kaydet (Kalıcı yapılandırma)
            SaveResourceFile(GetCurrentResourceName(), "runtime_config.json", json.encode(Config, { indent = true }), -1)
            print("^2[ONLY AC Web Panel]^0 Ayarlar web paneli uzerinden guncellendi ve runtime_config.json dosyasina kaydedildi.")
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

            if targetType == "vehicles" or targetType == "all" then
                for _, v in ipairs(GetAllVehicles()) do
                    if DoesEntityExist(v) then DeleteEntity(v) count = count + 1 end
                end
            end
            if targetType == "peds" or targetType == "all" then
                for _, p in ipairs(GetAllPeds()) do
                    if DoesEntityExist(p) and not IsPedAPlayer(p) then DeleteEntity(p) count = count + 1 end
                end
            end
            if targetType == "props" or targetType == "all" then
                for _, o in ipairs(GetAllObjects()) do
                    if DoesEntityExist(o) then DeleteEntity(o) count = count + 1 end
                end
            end

            sendResponse(res, 200, { success = true, cleared = count, type = targetType })
        end)
        return
    end

    -- Tanınmayan istek
    sendResponse(res, 404, { error = "not_found", message = "Bilinmeyen API endpointi." })
end)

-- Başlangıçta eğer runtime_config.json varsa onu yükle
CreateThread(function()
    local runtimeData = LoadResourceFile(GetCurrentResourceName(), "runtime_config.json")
    if runtimeData and runtimeData ~= "" then
        local success, decoded = pcall(json.decode, runtimeData)
        if success and type(decoded) == "table" then
            for k, v in pairs(decoded) do
                Config[k] = v
            end
            print("^2[ONLY AC]^0 Kaydedilmis Web Panel ayarlari (runtime_config.json) yuklendi.")
        end
    end
end)

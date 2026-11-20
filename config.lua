-- =========================================================================
-- ONLY AC v4.2.0 (ENTERPRISE & INTELLIGENCE EDITION) - GELİŞMİŞ KONFİGÜRASYON
-- Standartlar: Ocean Scanner, FeloxAC v4.1, SecuroX & Global FiveM Savunması
-- =========================================================================
Config = {}
Config.Version = "4.2.0"

-- =========================================================================
-- GENEL VE BİLDİRİM AYARLARI
-- =========================================================================

-- Discord Webhook Bağlantısı (Log ve Kanıtların gideceği kanal)
Config.DiscordWebhook = "" -- Discord Webhook URL'nizi buraya girin
Config.ServerName = "ONLY AC Enterprise"
Config.EmbedColor = 16711680 -- Kırmızı (#FF0000)

-- Web Yönetim Paneli Ayarları (Browser: http://SUNUCU_IP:PORT/ONLY_AC/)
Config.WebPanelEnabled = true
Config.WebPanelPassword = "admin" -- Web paneline giriş şifreniz

-- Varsayılan Ceza Eylemi: "ban", "kick" veya "log"
Config.DefaultAction = "ban"

-- Yetkili Muafiyet (Bypass) İzni (server.cfg: add_ace group.admin onlyac.bypass allow)
Config.AcePermission = "onlyac.bypass"

-- Ekran Görüntüsü Kanıtı (screenshot-basic kurulu ise otomatik çalışır)
Config.ScreenCaptureEnabled = true

-- Yükleme Ekranı / Spawn Koruma Süresi (Spawn esnasındaki haksız banları önler)
Config.SpawningGracePeriodSeconds = 15

-- =========================================================================
-- KORUMA MODÜLLERİ (TAM LİSTE - v4.1 ENTERPRISE)
-- =========================================================================
Config.Protections = {
    -- 1. Fizik, Hareket & Ragdoll
    AntiGodmode            = true, -- Klasik Native Ölümsüzlük ve Demi-God
    AntiLegitGodmode       = true, -- Hasar alır almaz canı anında geri 200 yapma (Fast Regen)
    AntiSpeedHack          = true, -- Hızlı koşma / SpeedHack koruması
    AntiNoclip             = true, -- Uçma / Noclip koruması
    AntiGroundNoclip       = true, -- Yerde yürüyor gibi gösteren yeni nesil noclip bypass tespiti
    AntiTeleport           = true, -- Anlık koordinat sıçraması koruması
    AntiSuperJump          = true, -- Süper zıplama hilesi
    AntiNoCollision        = true, -- Duvarlardan geçme (No-Collision)
    AntiRagdoll            = true, -- Taser/Düşme durumunda yere düşmeme (No-Ragdoll / Anti-Tase)
    AntiTinyPed            = true, -- Ped boyut küçültme/büyütme (Hitbox hilesi)
    AntiInfiniteStamina    = true, -- Sınırsız koşma / sonsuz stamina hilesi
    AntiLaunchPlayer       = true, -- Oyuncuyu gökyüzüne fırlatma hilesi engeli (Z-Velocity guard)

    -- 2. Görünmezlik & Görüş Hileleri
    AntiInvisibility       = true, -- Görünmezlik (Ghostmode / Alpha düşürme)
    AntiNightThermalVision = true, -- Termal ve Gece görüşü hilesi
    AntiSpectate           = true, -- Freecam ve yetkisiz gizli izleme
    AntiPedChange          = true, -- Yetkisiz ped / skin değişimi tespiti

    -- 3. Silah & Çatışma Korumaları
    AntiBlacklistedWeapons = true, -- Yasaklı ağır askeri silahlar
    AntiInfiniteAmmo       = true, -- Sınırsız mermi & Şarjörsüz ateş
    AntiDamageModifier     = true, -- Silah ve yumruk hasarını artırma hilesi (One-shot)
    AntiRapidFire          = true, -- Hızlı ateş etme (Rapid fire)
    AntiImpossibleDamage   = true, -- İmkansız mesafeden vurma / Magic Bullet koruması
    AntiAimbot             = true, -- Aimbot tespiti (kamera açısı ve ani yönelme analizi)
    AntiSilentAim          = true, -- Kemik ve LOS doğrulamalı sessiz aimbot engeli
    AntiWeaponPickup       = true, -- Yerde spawn edilen yetkisiz silah toplama engeli
    AntiMassKill           = true, -- Tek anda tüm sunucuya hasar verme (Kill-All) engeli
    AntiRPF                = true, -- Değiştirilmiş .RPF dosyaları (No Recoil, Fast Reload, Soft Aim) engeli

    -- 4. Araç Hileleri & Magneto
    AntiVehicleModifiers   = true, -- Araç hızlandırma ve tork hileleri
    AntiVehicleGodmode     = true, -- Ölümsüz araç ve anlık tamir hilesi
    AntiVehicleFly         = true, -- Karada giden araçla gökyüzünde uçma (Car Fly)
    AntiVehicleMagneto     = true, -- Araçları kendine çekme/fırlatma hilesi
    AntiVehicleSpawn       = true, -- Yetkisiz araç spawn tespiti
    AntiLaunchVehicle      = true, -- Araçları havaya fırlatma / trolleme engeli

    -- 5. Troll, Objeler, Efektler & Crasher
    AntiAttach             = true, -- Oyuncunun üzerine klozot/kamp ateşi/obje yapıştırma engeli
    AntiParticleSpam       = true, -- FPS düşüren partikül/havai fişek/patlama efekti spamı
    AntiClearTasks         = true, -- Başka oyuncuların animasyonunu uzaktan dondurma (Freeze)
    AntiMoneyDrop          = true, -- Para düşürme ve obje spam hilesi
    AntiCrasher            = true, -- Vanity, South, Sound & Net-Event crasher saldırılarını filtreleme

    -- 6. Sistem, Enjeksiyon & Native Bütünlüğü
    AntiNativeHook         = true, -- Lua native fonksiyonlarının hileyle hooklanmasını tespit etme
    AntiNUIDevTools        = true, -- F8 / NUI DevTools üzerinden kod enjeksiyonu denetimi
    AntiExplosionSpam      = true, -- Patlama spamı ve yasaklı patlama türleri
    AntiEntitySpam         = true, -- Toplu obje/araç basma (Crasher) koruması
    AntiPedSpam            = true, -- Toplu NPC basma koruması
    AntiHoneypotEvents     = true, -- Hile menüsü sahte eventleri
    AntiResourceStop       = true, -- Anti-Cheat veya sistem scriptlerini durdurma engeli
    AntiResourceInjection  = true, -- Yetkisiz resource başlatma / enjeksiyon tespiti
    AntiMenuDetection      = true, -- Bilinen hile menüsü eventlerini ve değişkenlerini yakalama
    AntiThreadFreeze       = true, -- Executor ile AC döngüsünü dondurma/öldürme tespiti
    AntiDupe               = true, -- Envanter ve para dupe (kopyalama) exploitlerini önleme
    AutoTxAdminBypass      = true, -- txAdmin yetki senkronizasyonunu anlık tespit etme
    UseExcludeZones        = true  -- Hastane/Admin bölgelerinde muafiyet (False-ban önleyici)
}

-- =========================================================================
-- 🧠 OYUNCU İSTİHBARAT & TEHDİT ANALİZİ AYARLARI (OCEAN / SECUROX MİMARİSİ)
-- =========================================================================
Config.ThreatScoring = {
    Enabled = true,                -- Tehdit ve risk puanlama sistemini aktif et
    MinThreatAlertScore = 45,      -- Bu puanın üstündeki girişler Discord loguna 'Yüksek Risk' olarak düşer
    AutoBanAltAccounts = true      -- Yasaklanmış bir oyuncunun yan hesabı (Ban Evasion) tespit edilirse anında banla
}

-- Event Tetikleme Hız Limiti (Trigger Flooding Guard)
Config.EventTriggerGuard = {
    Enabled = true,
    MaxTriggersPerSecond = 8       -- Bir oyuncunun saniyede atabileceği max kritik event
}

-- =========================================================================
-- EŞİK DEĞERLERİ VE LİMİTLER
-- =========================================================================
Config.MaxFootSpeed = 16.0         -- Yaya maksimum hız (m/s)
Config.MaxVehicleSpeedKMH = 350.0  -- Araç maksimum hız (km/s)
Config.MaxTeleportDistance = 85.0  -- 1 saniyede tolere edilen max teleport mesafesi

Config.MaxShootDistance = 250.0    -- Silah vuruş maksimum geçerli mesafe (metre)
Config.MaxWeaponDamage = 160       -- Tek vuruşta tolere edilen maksimum silah hasarı
Config.MaxMeleeDamage = 95         -- Yumruk/Bıçak maksimum hasarı

-- Fırlatma (Anti-Launch) Z-Eksen İvme Eşikleri (m/s)
Config.MaxPlayerZVelocity = 32.0   -- Yaya için izin verilen max dikey ivme
Config.MaxVehicleZVelocity = 38.0  -- Araç için izin verilen max dikey ivme

-- Aimbot Eşik Değerleri
Config.AimbotAngleThreshold = 15.0 -- Aimbot açı eşiği (derece cinsinden ani snap)
Config.AimbotCheckWindow = 5       -- Analiz edilecek son atış sayısı
Config.AimbotSnapCount = 4         -- Window içinde izin verilen maksimum ani snap sayısı

-- Stamina & Koşu Eşikleri
Config.StaminaCheckInterval = 2000          -- Stamina kontrol aralığı (ms)
Config.MaxConsecutiveSprintSeconds = 60     -- Stamina sıfırlanmadan max kesintisiz sprint süresi (sn)

-- Heartbeat / Watchdog
Config.HeartbeatInterval = 10000    -- Heartbeat sıklığı (10 saniye)
Config.HeartbeatTimeoutSeconds = 30 -- Timeout eşiği

-- Partikül Efekti Spam Limiti
Config.MaxParticlePerWindow = 4
Config.ParticleWindowSeconds = 3

-- Ped Spam Limiti
Config.MaxPedSpawnsPerWindow = 4
Config.PedWindowSeconds = 5

-- Resource Injection Limiti
Config.MaxResourceStartsPerWindow = 3
Config.ResourceWindowSeconds = 10

-- Entity Spam Limiti
Config.MaxEntitySpawnsPerWindow = 6
Config.EntityWindowSeconds = 5

-- Patlama Spam Limiti
Config.MaxExplosionsPerWindow = 3
Config.ExplosionWindowSeconds = 5

-- =========================================================================
-- 🗺️ BÖLGE MUAFİYETLERİ (EXCLUDE ZONES)
-- Hastane, Spawn ve Yetkili bölgelerinde yanlışlıkla teleport/noclip banı
-- atılmasını %100 önleyen koordinat çemberleri.
-- =========================================================================
Config.ExcludeZones = {
    { name = "Pillbox Hastanesi (Revive Bölgesi)", coords = vector3(298.6, -584.5, 43.2), radius = 55.0 },
    { name = "Mount Zonah Hastanesi", coords = vector3(-449.6, -340.8, 34.5), radius = 45.0 },
    { name = "Sandy Shores Hastanesi", coords = vector3(1839.2, 3672.9, 34.2), radius = 40.0 },
    { name = "Paleto Bay Kliniği", coords = vector3(-247.1, 6331.2, 32.4), radius = 40.0 },
    { name = "Legion Square (Merkezi Spawn)", coords = vector3(195.1, -933.8, 30.6), radius = 65.0 },
    { name = "Admin / Yetkili Adası", coords = vector3(-1037.0, -2737.0, 20.0), radius = 120.0 }
}

-- =========================================================================
-- 📦 GÜVENLİ OBJELER LİSTESİ (OBJECT WHITELIST)
-- Rol esnasında telefon çıkarma, defter tutma, şemsiye gibi masum RP
-- objelerinin haksız yere silinmesini veya ban atılmasını önler.
-- =========================================================================
Config.ObjectWhitelist = {
    [`prop_npc_phone_02`] = true,
    [`prop_phone_ing`] = true,
    [`prop_cs_phone_01`] = true,
    [`p_amb_phone_01`] = true,
    [`prop_anim_camera_01`] = true,
    [`prop_pencil_01`] = true,
    [`prop_notepad_01`] = true,
    [`p_amb_brolly_01`] = true,
    [`p_amb_brolly_02`] = true,
    [`prop_amb_beer_bottle`] = true,
    [`prop_cs_burger_01`] = true,
    [`prop_sandwich_01`] = true,
    [`prop_mug_01`] = true,
    [`prop_ld_flow_bottle`] = true,
    [`prop_fib_badge`] = true,
    [`prop_cop_badge`] = true,
    [`prop_radio_01`] = true
}

-- =========================================================================
-- YASAKLI LİSTELER
-- =========================================================================
Config.BlacklistedWeapons = {
    [`WEAPON_RPG`] = true,
    [`WEAPON_MINIGUN`] = true,
    [`WEAPON_HOMINGLAUNCHER`] = true,
    [`WEAPON_RAILGUN`] = true,
    [`WEAPON_GRENADELAUNCHER`] = true,
    [`WEAPON_COMPACTLAUNCHER`] = true,
    [`WEAPON_GRENADELAUNCHER_SMOKE`] = true,
    [`WEAPON_RAYPISTOL`] = true,
    [`WEAPON_RAYCARBINE`] = true,
    [`WEAPON_RAYMINIGUN`] = true,
    [`WEAPON_FIREWORK`] = true
}

Config.BlacklistedExplosions = {
    [1]  = true, [2]  = true, [4]  = true, [5]  = true,
    [6]  = true, [7]  = true, [8]  = true,
    [22] = true, [23] = true, [24] = true,
    [25] = true, [26] = true, [27] = true, [28] = true,
    [29] = true, [30] = true, [31] = true,
    [32] = true, [33] = true, [34] = true, [35] = true,
    [36] = true, [37] = true, [38] = true, [39] = true,
    [40] = true
}

Config.BlacklistedModels = {
    [`prop_gold_cont_01`] = true, [`p_ld_stinger_s`] = true,
    [`prop_ld_fnc_01`] = true,    [`prop_fnclink_03e`] = true,
    [`prop_fncsec_01a`] = true,   [`prop_weed_01`] = true,
    [`cargo_plane`] = true,       [`cutter`] = true,
    [`dump`] = true,              [`blimp`] = true, [`rhino`] = true,
    [`khanjali`] = true,          [`akula`] = true, [`hunter`] = true,
    [`hydra`] = true,             [`lazer`] = true, [`oppressor`] = true,
    [`oppressor2`] = true,        [`savage`] = true, [`strikeforce`] = true,
    [`bombushka`] = true
}

Config.HoneypotEvents = {
    -- ESX & QBCore Sahte Tetikleyicileri
    "esx:giveInventoryItem", "AdminMenu:giveBank", "AdminMenu:giveCash",
    "banking:transferMoney", "gcPhone:_internalAddMessage", "d0pamine:payMoney",
    "js:jailUser", "HCheat:TempDisableDetection", "kashactersS:DeleteCharacter",
    "df:bypassKey", "esx_ambulancejob:revive", "redengine:executeCode",
    "EulenCheats:trigger", "esx:setJob", "esx_society:withdrawMoney",
    "esx_billing:sendBill", "esx_policejob:handcuff", "esx_jailer:jail",
    "esx_ambulancejob:heal", "QBCore:Server:SetMetaData", "QBCore:CallCommand",
    
    -- Hile Menüsü / Executor Tuzakları
    "AdminMenu:spawnVehicle", "AdminMenu:teleport", "AdminMenu:noclip",
    "AdminMenu:godmode", "eulen:requestExecute", "lambda:executeCode",
    "skid:giveWeapon", "Los_Angeles:ServerCallback", "nexus:executeCode",
    "susano:bypassAuth", "lumia:triggerEvent", "south:execute"
}

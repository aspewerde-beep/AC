-- =========================================================================
-- 465 AC v4.2.0 - FIVEM ANTICHEAT & GÜVENLİK YAPILANDIRMASI
-- Modül Değerleri: true (Varsayılan Ceza) | "ban" | "kick" | "log" | "off" (veya false)
-- =========================================================================
Config = {}
Config.Version = "4.2.0"

-- =========================================================================
-- GENEL VE BİLDİRİM AYARLARI
-- =========================================================================

-- Discord Webhook Bağlantısı (Log ve Kanıtların gideceği kanal)
Config.DiscordWebhook = "" -- Discord Webhook URL'nizi buraya girin
Config.ServerName = "465 AC Security"
Config.EmbedColor = 9227186 -- Mint Emerald (#8ccbb2)

-- Web Yönetim Paneli Ayarları (Tarayıcı: http://SUNUCU_IP:PORT/ONLY_AC/)
Config.WebPanelEnabled = true
Config.WebPanelPassword = "admin" -- Lütfen üretim ortamında güçlü bir şifreyle değiştirin

-- Varsayılan Ceza Eylemi: "ban", "kick" veya "log"
Config.DefaultAction = "ban"

-- Yetkili Muafiyet (Bypass) İzni (server.cfg: add_ace group.admin 465ac.bypass allow)
Config.AcePermission = "465ac.bypass"
Config.LegacyAcePermission = "onlyac.bypass" -- Eski kurulumlarla geriye dönük uyumluluk

-- Ekran Görüntüsü Kanıtı (screenshot-basic kurulu ise otomatik çalışır)
Config.ScreenCaptureEnabled = true

-- Yükleme Ekranı / Spawn Koruma Süresi (Spawn esnasındaki haksız banları önler)
Config.SpawningGracePeriodSeconds = 18

-- Hareket & Hız ihlallerinde haksız tek-anlık gecikmeleri elemek için ardışık ihlal sayısı
Config.ViolationStrikes = 2

-- =========================================================================
-- KORUMA MODÜLLERİ (56+ MODÜL DESTEĞİ)
-- true -> Config.DefaultAction | false / "off" -> Kapalı
-- "log" -> Yalnızca Log & Webhook | "kick" -> Sunucudan At | "ban" -> Kalıcı Yasakla
-- =========================================================================
Config.Protections = {
    -- 1. Fizik, Hareket & Ragdoll
    AntiGodmode            = true, -- Native Ölümsüzlük, Demi-God & Anormal Can/Zırh
    AntiLegitGodmode       = true, -- Hasar alır almaz anında can fulleme (Fast Regen)
    AntiArmorHack          = true, -- Maksimum sınır üstü yetkisiz zırh (Armor Modifier)
    AntiSpeedHack          = true, -- Yaya ve araç hız tavanı kontrolü
    AntiNoclip             = true, -- Havada uçma / Noclip koruması
    AntiGroundNoclip       = true, -- Yerde yürüyormuş gibi gösteren noclip bypass tespiti
    AntiTeleport           = true, -- Anlık koordinat sıçraması koruması (Bölge & Grace korumalı)
    AntiSuperJump          = true, -- Süper zıplama hilesi
    AntiNoCollision        = true, -- Duvarlardan geçme (No-Collision)
    AntiRagdoll            = true, -- Taser/Düşme durumunda yere düşmeme (No-Ragdoll)
    AntiTinyPed            = true, -- Ped boyut küçültme/büyütme (Hitbox hilesi)
    AntiInfiniteStamina    = true, -- Sınırsız koşma / stamina hilesi
    AntiLaunchPlayer       = true, -- Oyuncuyu dikey Z-ekseninde fırlatma koruması

    -- 2. Görünmezlik & Görüş Hileleri
    AntiInvisibility       = true, -- Görünmezlik (Ghostmode / Alpha düşürme)
    AntiNightThermalVision = true, -- Termal ve Gece görüşü hilesi
    AntiSpectate           = true, -- Freecam ve yetkisiz gizli izleme
    AntiPedChange          = true, -- Yetkisiz ped / karakter modeli değişimi

    -- 3. Silah & Çatışma Korumaları
    AntiBlacklistedWeapons = true, -- Yasaklı ağır askeri silahlar ve izinsiz silah verme
    AntiInfiniteAmmo       = true, -- Sınırsız mermi & şarjör kilidi
    AntiDamageModifier     = true, -- Silah ve yumruk hasar çarpanı (One-Shot)
    AntiRapidFire          = true, -- Seri ateş etme (Rapid Fire)
    AntiImpossibleDamage   = true, -- İmkansız mesafeden vurma / Magic Bullet
    AntiAimbot             = true, -- Kamera açısı snap analizi ile aimbot tespiti
    AntiSilentAim          = true, -- Görüş açısı ve yönelme tutarlılığı (Silent Aim)
    AntiWeaponPickup       = true, -- Yerde spawn edilen yetkisiz silah toplama engeli
    AntiMassKill           = true, -- Kısa sürede çoklu hedef katliamı (Kill-All) engeli
    AntiRPF                = true, -- Modifiye oyun dosyaları (Weapon modifier / Fast reload)

    -- 4. Araç Hileleri & Magneto
    AntiVehicleModifiers   = true, -- Araç hız, güç ve tork çarpanı hilesi
    AntiVehicleGodmode     = true, -- Ölümsüz araç ve hasar almama
    AntiVehicleFly         = true, -- Kara aracını gökyüzünde uçurma (Car Fly)
    AntiVehicleMagneto     = true, -- Sürücülü araç çalma / manyetik çekme & fırlatma
    AntiVehicleSpawn       = true, -- Yetkisiz ağ sahipliğiyle araç spawn koruması
    AntiLaunchVehicle      = true, -- Araçları havaya fırlatma / trolleme engeli

    -- 5. Troll, Objeler, Efektler & Crasher
    AntiAttach             = true, -- Oyuncunun üzerine trol obje yapıştırma koruması (EMS güvenli)
    AntiParticleSpam       = true, -- FPS düşüren partikül ve efekt spamı
    AntiClearTasks         = true, -- Başka oyuncuların animasyonunu uzaktan dondurma
    AntiMoneyDrop          = true, -- Sahte para objesi / para paketi drop engeli
    AntiCrasher            = true, -- Ses, silah ve net-event crasher saldırı filtresi

    -- 6. Sistem, Enjeksiyon & Bütünlük
    AntiNativeHook         = true, -- Kritik istemci fonksiyon bütünlüğü denetimi
    AntiNUIDevTools        = true, -- Konsol / Executor global değişken & enjeksiyon denetimi
    AntiExplosionSpam      = true, -- Patlama spamı ve yasaklı patlama türleri
    AntiEntitySpam         = true, -- Toplu obje/araç basma (Crasher) koruması
    AntiPedSpam            = true, -- Toplu NPC basma koruması
    AntiHoneypotEvents     = true, -- Sahte tetikleyici (Honeypot Event) tuzakları
    AntiResourceStop       = true, -- Anti-Cheat durdurma engeli
    AntiResourceInjection  = true, -- Oyun içi yetkisiz yeni paket başlatma tespiti
    AntiMenuDetection      = true, -- Bilinen hile menüsü imzalarını yakalama
    AntiThreadFreeze       = true, -- İstemci döngüsü dondurma & eksik handshake bekçisi
    AntiDupe               = true, -- Hızlı mükerrer envanter/ekonomi event istismarı engeli
    AutoTxAdminBypass      = true, -- txAdmin yetkili otorite senkronizasyonu
    UseExcludeZones        = true  -- Hastane/Spawn bölgelerinde yanlış yasaklama önleyici muafiyet
}

-- =========================================================================
-- OYUNCU İSTİHBARAT & TEHDİT ANALİZİ AYARLARI
-- =========================================================================
Config.ThreatScoring = {
    Enabled = true,                -- Tehdit ve risk puanlama sistemini aktif et
    MinThreatAlertScore = 45,      -- Bu puanın üstündeki girişler Discord loguna düşer
    AutoBanAltAccounts = true      -- Yasaklı hesabın yan hesabı (Ban Evasion) tespit edilirse girişi engelle
}

-- Event Tetikleme Hız Limiti (Trigger Flooding & Anti-Dupe Guard)
Config.EventTriggerGuard = {
    Enabled = true,
    MaxTriggersPerSecond = 8,      -- Bir oyuncunun saniyede tetikleyebileceği max izlenen event
    WatchedEvents = {
        "esx_inventoryhud:tradePlayerItem",
        "inventory:server:UseItem",
        "qb-inventory:server:SetInventoryData",
        "qb-shops:server:buyItem",
        "esx_billing:sendBill",
        "qb-banking:server:TransferMoney"
    }
}

-- =========================================================================
-- EŞİK DEĞERLERİ VE LİMİTLER
-- =========================================================================
Config.MaxFootSpeed = 16.5         -- Yaya maksimum hız (m/s)
Config.MaxVehicleSpeedKMH = 360.0  -- Araç maksimum hız (km/s)
Config.MaxVehicleSpeedModifier = 1.65 -- İzin verilen max araç güç çarpanı
Config.MaxTeleportDistance = 90.0  -- Tek adımda tolere edilen max teleport mesafesi (metre)
Config.MaxHealth = 200             -- Maksimum oyuncu canı
Config.MaxArmor = 100              -- Maksimum oyuncu zırhı

Config.MaxShootDistance = 260.0    -- Silah vuruş maksimum geçerli mesafe (metre)
Config.MaxWeaponDamage = 165       -- Standart tek atışta tolere edilen max silah hasarı
Config.MaxHeavyWeaponDamage = 250  -- Sniper/Pompalı için max tek atış hasarı
Config.MaxMeleeDamage = 95         -- Yumruk/Bıçak maksimum hasarı

-- Fırlatma (Anti-Launch) Z-Eksen İvme Eşikleri (m/s)
Config.MaxPlayerZVelocity = 34.0   -- Yaya için izin verilen max dikey ivme
Config.MaxVehicleZVelocity = 40.0  -- Araç için izin verilen max dikey ivme

-- Aimbot & Silent Aim Eşikleri
Config.AimbotAngleThreshold = 18.0 -- Aimbot ani kamera sıçrama eşiği (derece)
Config.AimbotCheckWindow = 5       -- Analiz edilecek son atış penceresi
Config.AimbotSnapCount = 4         -- Pencere içinde tolere edilen max snap
Config.SilentAimMinDot = 0.45      -- Kamera bakış yönü ile hedef yönü arası min tutarlılık (-1..1)

-- Stamina & Koşu Eşikleri
Config.StaminaCheckInterval = 2000      -- Kontrol aralığı (ms)
Config.MaxConsecutiveSprintSeconds = 60 -- Kesintisiz sprint sınırı (sn)

-- Heartbeat / Watchdog
Config.HeartbeatInterval = 10000        -- Heartbeat sıklığı (ms)
Config.HeartbeatTimeoutSeconds = 30     -- Timeout eşiği (sn)
Config.HandshakeTimeoutSeconds = 40     -- Giriş handshake zaman aşımı (sn)

-- Spam Limitleri
Config.MaxParticlePerWindow = 4
Config.ParticleWindowSeconds = 3

Config.MaxPedSpawnsPerWindow = 4
Config.PedWindowSeconds = 5

Config.MaxResourceStartsPerWindow = 3
Config.ResourceWindowSeconds = 10

Config.MaxEntitySpawnsPerWindow = 6
Config.EntityWindowSeconds = 5

Config.MaxExplosionsPerWindow = 3
Config.ExplosionWindowSeconds = 5

-- =========================================================================
-- BÖLGE MUAFİYETLERİ (EXCLUDE ZONES)
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
-- İZİNLİ PED MODELLERİ (Multi-Char / RP Karakterleri)
-- =========================================================================
Config.WhitelistedPeds = {
    [`mp_m_freemode_01`] = true,
    [`mp_f_freemode_01`] = true
}

-- =========================================================================
-- GÜVENLİ OBJELER LİSTESİ (OBJECT WHITELIST)
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
    [`prop_radio_01`] = true,
    [`prop_ld_binbag_01`] = true,
    [`v_med_emptybed`] = true
}

-- =========================================================================
-- YASAKLI SİLAH, PATLAMA, OBJE VE PARA DROP LİSTELERİ
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

Config.MoneyDropModels = {
    [`prop_poly_bag_01`] = true,
    [`prop_cash_pile_01`] = true,
    [`prop_cash_pile_02`] = true,
    [`prop_money_bag_01`] = true,
    [`bkr_prop_money_sorted_01`] = true
}

Config.HoneypotEvents = {
    "esx:giveInventoryItem", "AdminMenu:giveBank", "AdminMenu:giveCash",
    "banking:transferMoney", "gcPhone:_internalAddMessage", "d0pamine:payMoney",
    "js:jailUser", "HCheat:TempDisableDetection", "kashactersS:DeleteCharacter",
    "df:bypassKey", "esx_ambulancejob:revive", "redengine:executeCode",
    "EulenCheats:trigger", "esx:setJob", "esx_society:withdrawMoney",
    "esx_billing:sendBill", "esx_policejob:handcuff", "esx_jailer:jail",
    "esx_ambulancejob:heal", "QBCore:Server:SetMetaData", "QBCore:CallCommand",
    "AdminMenu:spawnVehicle", "AdminMenu:teleport", "AdminMenu:noclip",
    "AdminMenu:godmode", "eulen:requestExecute", "lambda:executeCode",
    "skid:giveWeapon", "Los_Angeles:ServerCallback", "nexus:executeCode",
    "susano:bypassAuth", "lumia:triggerEvent", "south:execute"
}

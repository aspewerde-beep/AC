-- =========================================================================
-- 465 AC v4.2.0 - ORTAK YARDIMCI MODÜL (SHARED UTILITIES)
-- Modül bazlı Kapalı / Log / At / Ban çözümleme & Bölge / Gizlilik filtreleri
-- =========================================================================

ONLY_AC_Shared = {}

local VALID_ACTIONS = {
    off = true,
    log = true,
    kick = true,
    ban = true
}

-- Modül değerini ("off" | "log" | "kick" | "ban" | boolean) normalize et
function ONLY_AC_Shared.GetModuleAction(moduleName, fallbackAction)
    local protections = Config and Config.Protections
    if not protections then
        return "off"
    end

    local val = protections[moduleName]
    if val == nil or val == false then
        return "off"
    end

    if type(val) == "string" then
        local lower = val:lower()
        if VALID_ACTIONS[lower] then
            return lower
        end
        return fallbackAction or (Config and Config.DefaultAction) or "ban"
    end

    if val == true then
        return fallbackAction or (Config and Config.DefaultAction) or "ban"
    end

    return "off"
end

function ONLY_AC_Shared.IsModuleEnabled(moduleName)
    return ONLY_AC_Shared.GetModuleAction(moduleName) ~= "off"
end

-- Koordinatın güvenli bölge (Exclude Zone) içinde olup olmadığını kontrol et
function ONLY_AC_Shared.IsInExcludeZone(coords)
    if not coords or not ONLY_AC_Shared.IsModuleEnabled("UseExcludeZones") or not Config.ExcludeZones then
        return false, nil
    end

    for _, zone in ipairs(Config.ExcludeZones) do
        if zone.coords and zone.radius and #(coords - zone.coords) <= zone.radius then
            return true, zone.name
        end
    end
    return false, nil
end

-- İstemciye gönderilecek güvenli yapılandırma özeti (Webhook, şifre ve hassas sunucu ayarları gizlenir)
function ONLY_AC_Shared.BuildClientConfig()
    return {
        Version = Config.Version,
        HeartbeatInterval = Config.HeartbeatInterval or 10000,
        SpawningGracePeriodSeconds = Config.SpawningGracePeriodSeconds or 15,
        Protections = Config.Protections or {},
        MaxFootSpeed = Config.MaxFootSpeed or 16.0,
        MaxVehicleSpeedKMH = Config.MaxVehicleSpeedKMH or 350.0,
        MaxTeleportDistance = Config.MaxTeleportDistance or 85.0,
        MaxPlayerZVelocity = Config.MaxPlayerZVelocity or 32.0,
        MaxVehicleZVelocity = Config.MaxVehicleZVelocity or 38.0,
        MaxHealth = Config.MaxHealth or 200,
        MaxArmor = Config.MaxArmor or 100,
        MaxVehicleSpeedModifier = Config.MaxVehicleSpeedModifier or 1.65,
        AimbotAngleThreshold = Config.AimbotAngleThreshold or 15.0,
        AimbotCheckWindow = Config.AimbotCheckWindow or 5,
        AimbotSnapCount = Config.AimbotSnapCount or 4,
        SilentAimMinDot = Config.SilentAimMinDot or 0.55,
        StaminaCheckInterval = Config.StaminaCheckInterval or 2000,
        MaxConsecutiveSprintSeconds = Config.MaxConsecutiveSprintSeconds or 60,
        ViolationStrikes = Config.ViolationStrikes or 2,
        ExcludeZones = Config.ExcludeZones or {},
        ObjectWhitelist = Config.ObjectWhitelist or {},
        WhitelistedPeds = Config.WhitelistedPeds or {},
        BlacklistedWeapons = Config.BlacklistedWeapons or {}
    }
end

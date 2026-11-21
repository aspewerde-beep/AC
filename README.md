# 465 AC v4.2.0 — FiveM Enterprise Anti-Cheat Resource

Zero false-positive odaklı, sunucu otoriteli doğrulama, **51 yapılandırılabilir koruma modülü**, düşük istemci yükü ve gömülü **Web Yönetim Paneli** ile çalışan FiveM Anti-Cheat sistemi.

---

## Öne Çıkan Özellikler

- **4 Modlu Modül Yönetimi:** `Config.Protections` altındaki modüller tek tek `"ban"`, `"kick"`, `"log"`, `"off"` (`false`) veya `true` (`Config.DefaultAction`) olarak ayarlanabilir ve canlı web panelden yeniden başlatma gerektirmeden güncellenir.
- **Adaptif İstemci Döngüsü:** Silahsız, silahlı ve nişan alma durumlarına göre dinamik `Wait(...)` ölçeklemesi ile istemci yükünü minimumda tutar.
- **Sunucu Otoriteli Kontroller:** Session token & nonce korumalı event akışı, sunucu tarafı `GetPlayerInvincible` kontrolü, `txAdmin` admin bypass senkronizasyonu (`AutoTxAdminBypass`), OneSync popülasyon filtresi ve `screenshot-basic` kanıt entegrasyonu.
- **Akıllı İstihbarat & Ban Evasion:** HWID donanım token + `license` / `license2` / `fivem` / `discord` eşleştirmesi, risk puanlama, harici SS / Ocean tarama notları ve tek `deferrals` bağlantısı üzerinde çakışmasız kontrol.
- **Gömülü Web Yönetim Paneli:** `http://SUNUCU_IP:PORT/ONLY_AC/` üzerinden 51 modül matrisi, eşik ayarları, aktif oyuncu & lookup sorgusu, güvenli harita temizliği (oturulan araçlara ve whitelist objelere dokunmaz) ve ban yönetimi.

---

## Kurulum (`server.cfg`)

1. Kaynak klasörünü `resources/[security]/ONLY_AC` dizinine yerleştirin.
2. `config.lua` dosyasından **en azından** şu alanları düzenleyin:
   - `Config.WebPanelPassword` — Varsayılan `"admin"` şifresini güçlü bir şifreyle değiştirin.
   - `Config.DiscordWebhook` — Tespit ve kanıt logları için Discord Webhook URL ekleyin.
   - `Config.ServerName` — Sunucu adını belirleyin.
3. `server.cfg` dosyanıza başlatma ve yetki satırlarını ekleyin:

```cfg
# İsteğe bağlı: ekran kanıtı için once başlatın
ensure screenshot-basic

ensure ONLY_AC

# Yetkili Muafiyet (Bypass) İzni
add_ace group.admin 465ac.bypass allow
```

> **Geriye Dönük Uyumluluk:** `onlyac.bypass` izni (`Config.LegacyAcePermission`) ve `/onlyac_*` komut takma adları da otomatik olarak desteklenir.

---

## Yetkili Komutları

Tüm komutlar `465ac.bypass` (veya `onlyac.bypass`) ACE yetkisi gerektirir; sunucu konsolundan (`src == 0`) doğrudan kullanılabilir:

| Komut | Açıklama |
| --- | --- |
| `/465ac_check` | Aktif koruma katmanını ve istemci/sunucu durumunu doğrular |
| `/465ac_stats` | Toplam tespit, kick, ban ve aktif oyuncu sayısını yazar |
| `/465ac_kick [id] [sebep]` | Belirtilen oyuncuyu sunucudan atar |
| `/465ac_ban [id] [sebep]` | Oyuncuyu kalıcı olarak yasaklar |
| `/465ac_tempban [id] [saat] [sebep]` | Oyuncuya saatlik süreli ban uygular |
| `/465ac_unban [banId]` | Ban ID ile yasağı kaldırır (ör. `465-...`) |
| `/465ac_lookup [sorgu]` | İsim, lisans veya kimlik ile geçmiş/yan hesap arar |
| `/465ac_scan [license] [durum] [not]` | Oyuncu profiline harici SS / Ocean tarama notu işler |
| `/465ac_protect [modul] [ban\|kick\|log\|off]` | Koruma modülünü anlık değiştirir ve istemcilere gönderir |
| `/465ac_clear [vehicles\|peds\|props\|all]` | Boş araçları, NPC'leri veya whitelist dışı objeleri temizler |

---

## Script Entegrasyonu (Exports)

Kendi spawn, revive, ev içi ışınlanma veya ekonomi scriptlerinizde yanlış tespiti önlemek için `ONLY_AC` export'larını kullanabilirsiniz:

### Client Export
```lua
-- Teleport öncesi oyuncuya geçici ışınlanma izni verir (varsayılan 5000 ms)
exports["ONLY_AC"]:AllowTeleport(5000)
```

### Server Exports
```lua
-- Sunucudan oyuncuya geçici teleport muafiyeti ver
exports["ONLY_AC"]:AllowTeleport(source, 5000)

-- Özel scriptten harici tespit tetikle ("ban" | "kick" | "log")
exports["ONLY_AC"]:DetectPlayer(source, "Özel Kural İhlali", "Detay açıklaması", "ban", "CustomGuard")

-- Yasakla / Listele / Kaldır
exports["ONLY_AC"]:BanPlayer(source, "Sebep", 86400, "AdminAdı") -- duration saniye (nil ise kalıcı)
local bans = exports["ONLY_AC"]:GetBans()
exports["ONLY_AC"]:RemoveBan("465-12345")

-- İstihbarat sorgula & istatistik oku
local profiles = exports["ONLY_AC"]:LookupPlayer("license:...")
local stats = exports["ONLY_AC"]:GetStats()
```

---

## Web Panel Erişimi & Güvenlik Notları

- Tarayıcı üzerinden erişim adresi: `http://SUNUCU_IP:PORT/ONLY_AC/`
- Şifre yalnızca sunucuda doğrulanır ve `runtime_config.json` dosyasına yazılmaz (`Config.WebPanelPassword` her zaman `config.lua` üzerinden yönetilir).
- `GET /api/status` yanıtı şifreyi hiçbir zaman döndürmez ve kayıtlı `DiscordWebhook` bağlantısını maskeler.
- Arka arkaya 5 hatalı giriş denemesinde ilgili IP adresi 5 dakika kilitlenir.

# 🛡️ ONLY AC (v4.1.0 ENTERPRISE EDITION)
### Modern FiveM Anti-Cheat & Canlı Web Yönetim Paneli
**Standartlar:** FeloxAC v4.1, Echo & Phoenix Savunma Mimarisi

![FiveM](https://img.shields.io/badge/FiveM-Supported-brightgreen?style=for-the-badge&logo=fivem)
![Lua](https://img.shields.io/badge/Lua-5.4-blue?style=for-the-badge&logo=lua)
![Version](https://img.shields.io/badge/Version-4.1.0_Enterprise-orange?style=for-the-badge)
![Status](https://img.shields.io/badge/Open_Source-%25100_Backdoor_Free-success?style=for-the-badge)

**ONLY AC**, modern FiveM sunucuları için sıfırdan optimize edilmiş; harici veritabanı veya karmaşık backend gerektirmeyen, doğrudan FiveM'in yerleşik HTTP ve Event mimarisiyle çalışan, **%100 açık kaynaklı ve arka kapısız** kurumsal seviye bir hile koruma sistemidir.

---

## 🚀 v4.1.0 Enterprise İle Eklenen FeloxAC Standartları

* 🪝 **Anti Native Hook / Native Integrity:** Hile menülerinin (Susano, Lumia, South vb.) `GetEntityCoords`, `GetEntityHealth` gibi kritik native'leri hooklayarak AC'yi kör etmesini tespit eder.
* 🚀 **Anti-Launch Player & Vehicle:** Karakterlerin ve araçların dikey Z-ekseninde aniden gökyüzüne fırlatılmasını (Launch/Troll Crasher) engeller, hızı sıfırlar.
* 🚶 **Yerde Yürüyüş Noclip Bypass Tespiti (`AntiGroundNoclip`):** Karakteri yere sıfır yürüyüş animasyonunda tutup koordinat kaydırarak noclip atan yeni nesil bypass'ları yakalar.
* 🗺️ **Bölge Muafiyeti (`ExcludeZones`):** Hastane revive noktaları, Legion Square ve Yetkili adasında yanlışlıkla teleport/noclip banı atılmasını %100 önler.
* 📦 **Akıllı Obje Beyaz Listesi (`ObjectWhitelist`):** Rol esnasında telefon, defter, şemsiye, yiyecek gibi masum objelerin haksız yere silinmesini veya ban atılmasını önler.
* 💥 **Crasher Savunması (`AntiCrasher`):** Vanity, South ve ses/konuşma spamı (PlayPedAmbientSpeech) ile istemcileri çökerten paketleri sunucuda bloke eder.
* 🧹 **Admin Harita Temizliği (`/onlyac_clear`):** Sahipsiz araçları, NPC'leri ve zararlı objeleri tek komutla haritadan temizler.
* ⏳ **Yükleme Ekranı Koruması (`SpawningGracePeriodSeconds`):** Oyuncuların oyuna giriş anındaki spawn gecikmelerinde yanlışlıkla banlanmasını önler.

---

## 🌐 Canlı Web Yönetim Paneli (Web Dashboard)

Ekstra hiçbir Node.js, Python, MySQL veya harici porta gerek duymadan doğrudan FiveM'in yerleşik HTTP sunucusundan çalışır:

* **Erişim Adresi:** `http://SUNUCU_IP:30120/ONLY_AC/` *(Yerel test: `http://localhost:30120/ONLY_AC/`)*
* **Varsayılan Giriş Şifresi:** `admin` *( `config.lua` dosyasından `Config.WebPanelPassword` ile değiştirebilirsiniz )*

### Web Panelinden Neler Yapabilirsiniz?
1. **Canlı Koruma Modüllerini Yönetme:** 30'dan fazla koruma modülünü tek tıkla açıp kapatabilirsiniz.
2. **Eşik Değerleri ve Limitler:** Yaya hızı, araç hızı, silah hasarı, vuruş mesafesi ve aimbot toleranslarını webden kaydedebilirsiniz.
3. **Ban & Süreli Ban Yönetimi:** Aktif tüm yasaklı oyuncuları listeleyebilir, arama yapabilir ve tek tıkla yasak kaldırabilirsiniz.
4. **Anlık Log Akışı:** Sunucuda gerçekleşen tüm şüpheli hareketleri gerçek zamanlı izleyebilirsiniz.
5. **Kalıcı Yapılandırma:** Panelden yaptığınız tüm düzenlemeler `runtime_config.json` dosyasına kaydedilir ve sunucu yeniden başlatılsa dahi korunur.

---

## ⚡ Koruma Modülleri Özeti

| Kategori | Koruma Adı | Açıklama |
|---|---|---|
| **Sistem & Enjeksiyon** | `AntiNativeHook` | Lua native fonksiyonlarının hooklanmasını ve bellek manipülasyonunu yakalar. |
| **Savaş / Silah** | `AntiImpossibleDamage` | Duvar arkasından veya menzil dışından vurmayı sunucu seviyesinde iptal eder. |
| **Savaş / Silah** | `AntiDamageModifier` | Silah ve yumruk hasar çarpanlarını denetler (One-Shot Kill engeli). |
| **Savaş / Silah** | `AntiAimbot` | İnsan dışı kamera açısı sıçramalarını (Snap) tespit eder. |
| **Savaş / Silah** | `AntiMassKill` | Tek anda tüm sunucuya hasar verme (Kill-All) girişimlerini engeller. |
| **Savaş / Silah** | `AntiRPF` | Değiştirilmiş oyun dosyalarını (No Recoil, Fast Reload, Soft Aim) sınırlar. |
| **Fizik / Hareket** | `AntiGodmode` | Native ölümsüzlük ve hasar almama hilelerini engeller. |
| **Fizik / Hareket** | `AntiLegitGodmode` | Hasar aldığında canını hileyle anında dolduranları (Fast Regen) yakalar. |
| **Fizik / Hareket** | `AntiGroundNoclip` | Yere basıyormuş gibi gösterilen yeni nesil noclip bypass'ını yakalar. |
| **Fizik / Hareket** | `AntiLaunchPlayer` | Karakterin dikey olarak gökyüzüne fırlatılmasını engeller. |
| **Fizik / Hareket** | `AntiLaunchVehicle` | Araçların havaya fırlatılmasını ve trolleme eylemlerini durdurur. |
| **Fizik / Hareket** | `AntiSpeedHack` | Yaya ve araç hız tavanını denetler. |
| **Fizik / Hareket** | `AntiInfiniteStamina` | Koşarken tükenmeyen sınırsız dayanıklılığı tespit eder. |
| **Dünya / Saldırı** | `AntiCrasher` | Vanity, South ve Sound crasher exploit paketlerini çöpe atar. |
| **Dünya / Saldırı** | `AntiEntitySpam` | Toplu araç/obje basarak sunucuyu dondurmayı engeller. |
| **Dünya / Saldırı** | `AntiExplosionSpam`| Yasaklı patlama türlerini ve toplu patlamaları engeller. |

---

## 🎮 Yetkili Komutları

| Komut | Açıklama |
|---|---|
| `/onlyac_check <id>` | Oyuncunun ping, can, zırh, koordinat ve ID bilgilerini detaylı listeler. |
| `/onlyac_stats` | Sunucu uptime, toplam yakalama ve ban istatistiklerini gösterir. |
| `/onlyac_clear <vehicles\|peds\|props\|all>` | Haritadaki sahipsiz araç, NPC ve objeleri tek tıkla temizler. |
| `/onlyac_kick <id> <sebep>` | Belirtilen oyuncuyu sunucudan anında atar. |
| `/onlyac_ban <id> <sebep>` | Belirtilen oyuncuyu kalıcı olarak yasaklar. |
| `/onlyac_tempban <id> <saat> <sebep>` | Belirtilen oyuncuyu saatlik süreli yasaklar. |
| `/onlyac_protect <Modül> <on/off>` | Oyun içinden anlık olarak koruma modülünü açıp kapatır. |

---

## 📦 Kurulum

1. `ONLY_AC` klasörünü sunucunuzun `resources/` dizinine yerleştirin.
2. `server.cfg` içerisine ekleyin:
   ```cfg
   ensure ONLY_AC

   # Yetkili Bypass izni:
   add_ace group.admin onlyac.bypass allow
   ```
3. `config.lua` dosyasından şifrenizi ve Discord Webhook'unuzu belirleyin:
   ```lua
   Config.WebPanelPassword = "guclu_bir_sifre"
   Config.DiscordWebhook = "https://discord.com/api/webhooks/..."
   ```
4. Tarayıcınızdan `http://SUNUCU_IP:30120/ONLY_AC/` adresine giderek yönetim panelinize bağlanın!

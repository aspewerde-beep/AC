/* =========================================================================
   465 AC (https://465.lol/) - TR / EN Çoklu Dil ve Scroll-Spy Yardımcıları
   ========================================================================= */

const I18N_465 = {
  tr: {
    nav_catalog: "Korumalar",
    nav_config: "Yapılandırma",
    nav_guarantee: "Güvence",
    nav_faq: "SSS",
    nav_tools: "465 Tools ↗",

    hero_pill: "FiveM için geliştirildi",
    hero_h1_top: "Sunucunu ileri taşıyan",
    hero_h1_bot: "FiveM koruması.",
    hero_sub: "Sunucu taraflı savaş doğrulama, temiz yapılandırma ve düşük kaynak tüketimi. Oyuncularına hilesiz ve akıcı bir deneyim sun.",
    hero_btn_explore: "Paketleri keşfet ↓",
    hero_btn_support: "Satış öncesi destek",
    trust_1: "Anında kurulum",
    trust_2: "0.00ms Resmon",
    trust_3: "Kurulum desteği",
    scroll_cue: "KEŞFET",

    cat_eyebrow: "KATALOG",
    cat_title_1: "Sunucuna güç katan ",
    cat_title_2: "korumalar",
    cat_search: "Paket veya modül ara…",

    how_eyebrow: "NASIL ÇALIŞIR",
    how_s1_t: "Paketini seç",
    how_s1_d: "Katalogdan sunucuna uygun koruma ve istihbarat paketini seç; canlı modül önizlemelerini incele.",
    how_s2_t: "Tek satırda kur",
    how_s2_d: "465_AC klasörünü resources içine atıp server.cfg'ye ekle; harici veritabanı kurmadan dakikalar içinde çalıştır.",
    how_s3_t: "Canlı yönet & koru",
    how_s3_d: "Tarayıcı panelinden modülleri off/log/kick/ban olarak ayarla, Discord webhook üzerinden anlık bildirim al.",

    cfg_eyebrow: "KOLAY YAPILANDIRMA",
    cfg_title_1: "Kod bilmeden ",
    cfg_title_2: "dakikalar içinde ",
    cfg_title_3: "ayarla",
    cfg_desc: "Her koruma modülünün davranışı açık ve okunaklı yapılandırma dosyalarıyla değiştirilir. Neyin ne işe yaradığı satırında yazar.",
    cfg_b1: "Modül bazlı off / log / kick / ban aksiyon seçimi",
    cfg_b2: "Exclude Zones ve Object Whitelist ile sıfır false-ban",
    cfg_b3: "Takıldığın yerde Discord'dan destek ve kurulum yardımı",

    rev_eyebrow: "MÜŞTERİ YORUMLARI",
    rev_title_1: "Sunucu sahipleri ",
    rev_title_2: "ne diyor?",

    gua_eyebrow: "GÜVENCE",
    gua_title_1: "Satın aldıktan sonra da ",
    gua_title_2: "yanındayız",
    g1_t: "Kaynak dostu kod",
    g1_d: "Her modül düşük CPU ve bellek tüketimi gözetilerek yazıldı. İstemcide 0.00–0.01ms hedefler.",
    g2_t: "Sunucu taraflı otorite",
    g2_d: "Hasar, patlama, obje basma ve mesafe kontrolleri istemciye güvenmeden doğrudan sunucuda doğrulanır.",
    g3_t: "Sürekli destek",
    g3_d: "Kurulumda veya false-ban ayarlamasında sorun yaşadığında ekibimiz birebir yapılandırma desteği verir.",

    faq_eyebrow: "SIKÇA SORULAN SORULAR"
  },
  en: {
    nav_catalog: "Protections",
    nav_config: "Configuration",
    nav_guarantee: "Guarantee",
    nav_faq: "FAQ",
    nav_tools: "465 Tools ↗",

    hero_pill: "Built for FiveM",
    hero_h1_top: "FiveM security that",
    hero_h1_bot: "pushes your server.",
    hero_sub: "Server-authoritative combat verification, clean Lua configuration, and ultra-low resource usage. Give your community a smooth, cheat-free experience.",
    hero_btn_explore: "Explore packages ↓",
    hero_btn_support: "Pre-sales support",
    trust_1: "Instant setup",
    trust_2: "0.00ms Resmon",
    trust_3: "Setup assistance",
    scroll_cue: "EXPLORE",

    cat_eyebrow: "CATALOG",
    cat_title_1: "Protections that ",
    cat_title_2: "power your server",
    cat_search: "Search package or module…",

    how_eyebrow: "HOW IT WORKS",
    how_s1_t: "Choose your package",
    how_s1_d: "Pick the protection suite tailored to your player count and review live module controls before deploying.",
    how_s2_t: "Deploy in one line",
    how_s2_d: "Drop 465_AC into your resources folder and ensure it in server.cfg — no external database or Node.js required.",
    how_s3_t: "Monitor & protect live",
    how_s3_d: "Switch any module between off/log/kick/ban from the built-in web panel and receive instant Discord alerts.",

    cfg_eyebrow: "EASY CONFIGURATION",
    cfg_title_1: "Configure in minutes ",
    cfg_title_2: "without coding",
    cfg_title_3: "",
    cfg_desc: "Every detection's behavior is controlled through clean, well-documented config files. Every option is explained inline.",
    cfg_b1: "Per-module off / log / kick / ban action modes",
    cfg_b2: "Exclude Zones & Object Whitelist prevent false bans",
    cfg_b3: "Direct Discord setup help whenever you need it",

    rev_eyebrow: "TESTIMONIALS",
    rev_title_1: "What server owners ",
    rev_title_2: "are saying",

    gua_eyebrow: "GUARANTEE",
    gua_title_1: "With you even ",
    gua_title_2: "after launch",
    g1_t: "Resource-friendly code",
    g1_d: "Written with minimal loops and low CPU footprint, targeting 0.00–0.01ms idle resmon on clients.",
    g2_t: "Server-side authority",
    g2_d: "Weapon damage, explosions, entity spawns, and range checks are validated server-side instead of trusting clients.",
    g3_t: "Ongoing support",
    g3_d: "If you ever run into setup issues or false-positive tuning, our team helps you dial in your config directly.",

    faq_eyebrow: "FREQUENTLY ASKED QUESTIONS"
  }
};

function get465Lang() {
  return localStorage.getItem("ac465_lang") || "tr";
}

function set465Lang(lang) {
  localStorage.setItem("ac465_lang", lang);
  apply465Lang(lang);
}

function apply465Lang(lang) {
  const dict = I18N_465[lang] || I18N_465.tr;
  document.documentElement.lang = lang;

  document.querySelectorAll("[data-i18n]").forEach((el) => {
    const key = el.getAttribute("data-i18n");
    if (dict[key] !== undefined) el.textContent = dict[key];
  });

  document.querySelectorAll("[data-i18n-ph]").forEach((el) => {
    const key = el.getAttribute("data-i18n-ph");
    if (dict[key] !== undefined) el.placeholder = dict[key];
  });

  document.querySelectorAll("[data-lang-btn]").forEach((btn) => {
    btn.classList.toggle("active", btn.getAttribute("data-lang-btn") === lang);
  });
}

document.addEventListener("DOMContentLoaded", () => {
  apply465Lang(get465Lang());

  const mobBtn = document.getElementById("mobileNavToggle");
  const navLinks = document.getElementById("primaryNavLinks");
  if (mobBtn && navLinks) {
    mobBtn.addEventListener("click", () => navLinks.classList.toggle("open"));
  }

  // Scroll-to-top visibility + Scroll-Spy for top navbar & left floating dock
  const scrollBtn = document.getElementById("scrollTopBtn");
  const trackedSections = Array.from(document.querySelectorAll("[data-section-id]"));
  const dockItems = Array.from(document.querySelectorAll(".left-dock [data-dock]"));
  const topNavItems = Array.from(document.querySelectorAll(".nav-links [data-nav]"));

  function updateScrollState() {
    if (scrollBtn) {
      scrollBtn.classList.toggle("visible", window.scrollY > 420);
    }

    if (!trackedSections.length) return;
    let activeId = trackedSections[0].getAttribute("data-section-id");
    const offset = window.scrollY + 220;

    for (const sec of trackedSections) {
      if (sec.offsetTop <= offset) {
        activeId = sec.getAttribute("data-section-id");
      }
    }

    dockItems.forEach((d) => d.classList.toggle("active", d.getAttribute("data-dock") === activeId));
    topNavItems.forEach((n) => n.classList.toggle("active", n.getAttribute("data-nav") === activeId));
  }

  window.addEventListener("scroll", updateScrollState, { passive: true });
  updateScrollState();
});

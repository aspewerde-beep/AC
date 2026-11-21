fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name '465_AC'
author '465 AC Team'
description '465 AC v4.2.0 - FiveM Anticheat & Dahili Web Yönetim Paneli'
version '4.2.0'

shared_scripts {
    'config.lua',
    'shared/utils.lua'
}

client_scripts {
    'client/main.lua',
    'client/detections.lua'
}

server_scripts {
    'server/banlist.lua',
    'server/intelligence.lua',
    'server/main.lua',
    'server/detections.lua',
    'server/combat_guard.lua',
    'server/heartbeat_watchdog.lua',
    'server/web_api.lua'
}

files {
    'web/index.html'
}

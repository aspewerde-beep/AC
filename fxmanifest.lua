fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ONLY_AC'
author 'ONLY AC Team'
description 'ONLY AC v4.2.0 Ultimate Intelligence - Gelişmiş Anti-Cheat & Web Dashboard'
version '4.2.0'

shared_scripts {
    'config.lua'
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

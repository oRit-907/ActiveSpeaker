fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'oRit_907'
description 'A simple script to show who is currently talking for PMA-Voice.'
version '2.2.0'

repository 'https://github.com/oRit-907/ActiveSpeaker'

shared_scripts {
    'config.lua',
    'locales.lua',
    'shared.lua'
}

client_script 'client.lua'

server_scripts {
    'server.lua',
    'version.lua'
}

--Love you guys.

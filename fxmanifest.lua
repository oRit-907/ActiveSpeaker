fx_version 'cerulean'
game 'gta5'

name 'ActiveSpeaker'
author 'Rage City'
description 'Visual indicator above a players head showing who is talking, powered by pma-voice'
version '1.0.2'

client_script 'client.lua'
server_script 'server.lua'

-- pma-voice is required, but it is checked at runtime in server.lua rather than
-- declared here, so servers running a renamed copy of it still start.

fx_version 'cerulean'
game 'gta5'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua',
    'locales/en.lua',
    'locales/*.lua',
    '@ox_lib/init.lua'
}

client_script 'client/main.lua'

server_script 'server/main.lua'

lua54 'yes'
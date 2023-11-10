fx_version 'cerulean'
game 'gta5'

description 'QBX-TowJob'
version '1.0.0'

modules {
    	'qbx_core:utils'
}

shared_scripts {
	'@ox_lib/init.lua',
	'@qbx_core/import.lua',
	'@qb-core/shared/locale.lua',
	'config.lua',
	'locales/en.lua',
}

client_scripts {
	'@PolyZone/client.lua',
	'@PolyZone/BoxZone.lua',
	'@PolyZone/ComboZone.lua',
	'client/main.lua'
}

server_script 'server/main.lua'

provide 'qb-towjob'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

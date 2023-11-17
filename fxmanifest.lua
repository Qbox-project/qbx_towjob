fx_version 'cerulean'
game 'gta5'

description 'QBX_TowJob'
repository 'https://github.com/Qbox-project/qbx_towjob'
version '1.0.0'

shared_scripts {
	'@ox_lib/init.lua',
	'@qbx_core/modules/utils.lua',
	'@qbx_core/shared/locale.lua',
  'config.lua',
	'locales/en.lua',
	'locales/*.lua',
	'config.lua'
}

client_scripts {
	'@qbx_core/modules/playerdata.lua',
	'@PolyZone/client.lua',
	'@PolyZone/BoxZone.lua',
	'@PolyZone/ComboZone.lua',
	'client/main.lua',
}

server_script 'server/main.lua'

provide 'qb-towjob'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

-- Run using Lua 5.1/LuaJIT, or Lua 5.4 for the API-stubbed tests. No game,
-- browser, DLL or user settings are touched by this test.
local real_dofile = dofile
local settings, flags, enabled, opened, sounds, notices = {}, {}, {}, {}, {}, {}
local world_seed, plus_count, player_x, player_y, world_columns = '195331', nil, 10, 20, 70
local shell_codes, key_down = {}, true
local function equal(actual, expected, label)
  assert(actual == expected, (label or '') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
function dofile() end
function dofile_once() end
function ModRegisterAudioEventMappings() end
function ModSettingGet(key) return settings[key] end
function GamePlaySound(bank, event, x, y) sounds[#sounds+1] = {bank=bank,event=event,x=x,y=y} end
function GamePrint(text) notices[#notices+1] = text end
function EntityGetWithTag(tag) return tag=='player_unit' and {1} or {} end
function EntityGetTransform() return player_x, player_y end
function GameGetCameraPos() return player_x, player_y end
function GetParallelWorldPosition(x) return math.floor((x+world_columns*256)/(world_columns*512)) end
function BiomeMapGetSize() return world_columns,48 end
function HasFlagPersistent(flag) return flags[flag] == true end
function ModIsEnabled(id) return enabled[id] == true end
function SessionNumbersGetValue() return plus_count end
function StatsGetValue() return world_seed end
function InputIsKeyJustDown() return key_down end
function async() error('Opening a map must not queue a delayed coroutine') end
function wait() error('Opening a map must not wait for game frames') end
local shell = {ShellExecuteA=function(_,operation,file,params)
 opened[#opened+1] = {operation=operation,file=file,params=params}
 return table.remove(shell_codes,1) or 33
end}
package.preload.ffi = function() return {load=function() return shell end,cdef=function() end,cast=function(_,value) return value end} end
real_dofile('noitamap/init.lua')
equal(sounds[1].bank, 'mods/noitamap/files/audio/noitamap.bank')
equal(sounds[1].event, 'noitamap/dummy_sound')
local function reset()
 settings, flags, enabled, opened, sounds, notices = {}, {}, {}, {}, {}, {}
 world_seed,plus_count,player_x,player_y,world_columns='195331',nil,10,20,70
 shell_codes,key_down={},true
 current_world_seed=nil
end
local function check(name, fn) reset(); fn(); print('PASS '..name) end
check('normal mode tolerates missing NG+ count', function()
 equal(get_map_url_param(),'dynamic-main-branch')
 local url=construct_url()
 assert(url:find('&se=195331',1,true)); assert(url:find('&src=mod',1,true))
 assert(url:find('&u=AAAAAAA',1,true)); assert(url:find('&p=1.',1,true))
end)
check('canonical unlock bit order',function()
 flags.card_unlocked_sea_lava=true;flags.card_unlocked_destruction=true
 equal(get_unlocks_param(),'AQAAABA')
end)
check('maximum and zero seeds are exact decimal values',function()
 world_seed='4294967295'; assert(construct_url():find('&se=4294967295&',1,true))
 world_seed='0';assert(construct_url():find('&se=0&',1,true))
end)
check('unavailable seed never opens an unrelated Daily',function()
 world_seed=nil;launch_browser();equal(#opened,0);equal(#notices,1)
end)
check('new live seed is read on each launch',function()
 OnPlayerSpawned(1);world_seed='92';assert(construct_url():find('&se=92&',1,true))
end)
check('mode URLs exist on the website',function()
 enabled.apotheosis=true;equal(get_map_url_param(),'apotheosis-beta-branch')
 plus_count='1';equal(get_map_url_param(),'apotheosis-new-game-plus')
 enabled={Noitavania=true};equal(get_map_url_param(),'noitavania-new-game-plus')
 plus_count=nil;equal(get_map_url_param(),'noitavania')
 enabled={Nightmare=true};equal(get_map_url_param(),'nightmare-main-branch')
 enabled={};plus_count='2';equal(get_map_url_param(),'new-game-plus-main-branch')
end)
check('parallel-world clamping uses actual biome width and keeps its offset local',function()
 world_columns=100;player_x=3*51200+100;player_y=-2.8
 local url=construct_url();assert(url:find('?x=51300&y=-3&',1,true));equal(new_pw,nil)
 player_x=-3*51200-100;assert(construct_url():find('?x=-51300&',1,true))
end)
check('configured browser arguments are quoted and failure falls back to URL handler',function()
 settings['noitamap.BROWSER']='custom';settings['noitamap.BROWSER_CUSTOM_PATH']='C:\\Browser path\\browser.exe'
 shell_codes={2,33};equal(open_url('https://noitamap.com/?se=1&src=mod'),true)
 equal(opened[1].params,'"https://noitamap.com/?se=1&src=mod"');equal(opened[2].params,nil)
end)
check('complete launch failure is reported',function()
 shell_codes={2};launch_browser();equal(#notices,1)
end)
check('M opens immediately with the correct sound bank and no queued launches',function()
 OnWorldPostUpdate();equal(#opened,1);equal(#sounds,1)
 equal(sounds[1].bank,'mods/noitamap/files/audio/noitamap.bank');equal(sounds[1].event,'noitamap/what')
 key_down=false;OnWorldPostUpdate();equal(#opened,1)
end)
check('map and sound toggles remain independent',function()
 settings['noitamap.PLAY_MAP_OPENING_SOUND']=false;OnWorldPostUpdate();equal(#opened,1);equal(#sounds,0)
 opened={};settings['noitamap.MAP_OPENING_ENABLED']=false;settings['noitamap.PLAY_MAP_OPENING_SOUND']=true
 settings['noitamap.PLAY_SPICY_SOUND']=true;OnWorldPostUpdate();equal(#opened,0);equal(sounds[1].event,'noitamap/where')
end)
check('local and preview website settings preserve handoff markers',function()
 settings['noitamap.MAP_WEBSITE']='localhost:5173';assert(construct_url():find('http://localhost:5173/',1,true)==1)
 settings['noitamap.MAP_WEBSITE']='dynamic-map.noitamap.com';assert(construct_url():find('https://dynamic-map.noitamap.com/',1,true)==1)
end)
print('12 runtime checks passed')

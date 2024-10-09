dofile("data/scripts/game_helpers.lua")
dofile_once("data/scripts/lib/utilities.lua")
dofile_once("data/scripts/lib/coroutines.lua")
dofile_once("data/scripts/debug/keycodes.lua")
dofile("data/scripts/lib/mod_settings.lua")

-- Register custom audio bank
ModRegisterAudioEventMappings("mods/noitamap/files/audio/GUIDs.txt")

-- "Play" empty sound so the sounds work
GamePlaySound("mods/noitamap/files/audio/noitamap.bank", "dummy_sound", 0, 0)

-- Browser opening snippet provided by Dexter
local ffi = require("ffi")
local shell32 = ffi.load("Shell32.dll")

ffi.cdef([[
typedef void* HANDLE;
typedef HANDLE HINSTANCE;
typedef HANDLE HWND;
typedef char CHAR;
typedef const CHAR *LPCSTR;
typedef int INT;

HINSTANCE ShellExecuteA(
  /* in, optional */ HWND   hwnd,
  /* in, optional */ LPCSTR lpOperation,
  /* in */           LPCSTR lpFile,
  /* in, optional */ LPCSTR lpParameters,
  /* in, optional */ LPCSTR lpDirectory,
  /* in */           INT    nShowCmd
);
]])

-- Executes launching command
function win32_open(path)
    local SHOWNORMAL = 1
    shell32.ShellExecuteA(nil, "open", path, nil, nil, SHOWNORMAL)
end

function launch_browser()

    local currentMapPos = construct_url()
    win32_open(currentMapPos)

end

function play_where_sound()
    if ModSettingGet("noitamap.PLAY_MAP_OPENING_SOUND") == true then
        GamePlaySound("mods/noitmap/files/audio/noitmap.bank",
                      "noitamap/create", get_player_pos())
    end
end

-- Should work even the player is polymorphed, thanks Dexter
function get_player()
    local player = EntityGetWithTag("player_unit")[1] or
                       EntityGetWithTag("polymorphed_player")[1] or nil
    if player ~= nil then return player end
end

-- Potential alternative approach to getting player coords from gokis cheat ui: 
-- safe_string_format( ModSettingGet( "ui_timer_hits.position_string" ), math.floor( x ) )
-- safe_string_format( ModSettingGet( "ui_timer_hits.depth_string" ), math.floor( y / 10 ) )

function get_player_pos()
    local ourPlayer = get_player()
    local pos_x, pos_y = 0, 0
    if ourPlayer then pos_x, pos_y = EntityGetTransform(ourPlayer) end
    return pos_x, pos_y
end

-- Building URL to pass to the browser opening function
function construct_url()
    local x_coord_url_param, y_coord_url_param = get_player_pos()
    x_coord_url_param = tostring(math.floor(x_coord_url_param))
    y_coord_url_param = tostring(math.floor(y_coord_url_param))
    local zoom_param = "930"
    local map_param = get_map_url_param()

    local base_url = ModSettingGet("noitamap.MAP_WEBSITE") or
                         "https://noitamap.com"

    -- Construct the full URL with the parameters
    local full_url_string = base_url .. "/?x=" .. x_coord_url_param .. "&y=" ..
                                y_coord_url_param .. "&zoom=" .. zoom_param ..
                                "&map=" .. map_param
    return full_url_string
end

-- Using mod detection to open correct map
function get_map_url_param()
    local newgame_n = tonumber(SessionNumbersGetValue("NEW_GAME_PLUS_COUNT"))
    if ModIsEnabled("Nightmare") or ModIsEnabled("nightmare") then
        return "nightmare-main-branch"
    elseif ModIsEnabled("Apotheosis") or ModIsEnabled("apotheosis") then
        return "apotheosis"
    elseif ModIsEnabled("Noitavania") or ModIsEnabled("noitavania") then
        return "noitavania"
    elseif ModIsEnabled("biome-plus") or ModIsEnabled("Alternate Biomes") then
        return "alternate-biomes"
    elseif newgame_n >= 1 then
        return "new-game-plus-main-branch"
    else
        return "regular-main-branch"
    end
end

function OnPlayerSpawned(player_entity)
    GamePlaySound("mods/noitamap/files/audio/noitamap.bank",
                  "noitamap/dummy_sound", 0, 0)

end

-- used to detect settings changes
-- wiki: OnModSettingsChanged "Note: This callback doesn't appear to work. Modders have resorted to using OnPausedChanged instead to detect potential settings changes."
function OnWorldPostUpdate()

    if InputIsKeyJustDown(16) and ModSettingGet("noitamap.MAP_OPENING_ENABLED") ==
        true then
        if ModSettingGet("noitamap.PLAY_MAP_OPENING_SOUND") == true then
            async(function()
                play_where_sound()
                wait(70)
                launch_browser()
            end)
        else
            launch_browser()
        end
    elseif InputIsKeyJustDown(16) and
        ModSettingGet("noitamap.PLAY_MAP_OPENING_SOUND") == true then
        play_where_sound()
    end
end

function OnWorldPreUpdate() wake_up_waiting_threads(1) end

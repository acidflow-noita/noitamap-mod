dofile("data/scripts/game_helpers.lua")
dofile_once("data/scripts/lib/utilities.lua")
dofile_once("data/scripts/lib/coroutines.lua")
dofile_once("scripts/detect_game_mode.lua")
dofile_once("scripts/get_player_pos.lua")
dofile_once("scripts/construct_url.lua")
dofile_once("scripts/keys.lua")

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

-- Should work even the player is polymorphed, thanks Dexter
function get_player()
    local player = EntityGetWithTag("player_unit")[1] or
                       EntityGetWithTag("polymorphed_player")[1] or nil
    if player ~= nil then return player[1] end
end

-- Potential alternative approach to getting player coords from gokis cheat ui: 
-- safe_string_format( ModSettingGet( "ui_timer_hits.depth_string" ), math.floor( y / 10 ) )
function get_player_pos()
    local ourPlayer = get_player()
    if not ourPlayer then return 0, 0 end
    local pos_x, pos_y = EntityGetTransform(ourPlayer)
    GlobalsSetValue("ourPlayer_pos_x", pos_x)
    GlobalsSetValue("ourPlayer_pos_y", pos_y)
    return EntityGetTransform(ourPlayer)
end

-- Building URL to pass to the browser opening function
function construct_url()
    local x_coord_url_param = tostring(GlobalsGetValue("ourPlayer_pos_x"))
    local y_coord_url_param = tostring(GlobalsGetValue("ourPlayer_pos_y"))
    local zoom_param = "900"
    local map_param = tostring(GlobalsGetValue("map_name"))

    if ModSettingGet("noitamap.mapwebsite") ~= nil then
        base_url = ModSettingGet("noitamap.mapwebsite")
    else
        base_url = "https://noitamap.com"
    end

    -- Construct the full URL with the parameters
    local full_url = base_url .. "/?x=" .. x_coord_url_param .. "&y=" ..
                         y_coord_url_param .. "&zoom=" .. zoom_param .. "&map=" ..
                         map_param
    GlobalsSetValue("full_url_string", full_url)

    return full_url_string
end

-- debug
function informPlayers1() GamePrintImportant(full_url_string) end

-- Using mod detection to open correct map
function set_map_url_param()
    if ModIsEnabled("Nightmare") then
        GlobalsSetValue("map_name", "nightmare-main-branch")
    elseif ModIsEnabled("nightmare") then
        GlobalsSetValue("map_name", "nightmare-main-branch")
    elseif ModIsEnabled("Apotheosis") then
        GlobalsSetValue("map_name", "apotheosis")
    elseif ModIsEnabled("apotheosis") then
        GlobalsSetValue("map_name", "apotheosis")
    elseif ModIsEnabled("Noitavania") then
        GlobalsSetValue("map_name", "noitavania")
    elseif ModIsEnabled("noitavania") then
        GlobalsSetValue("map_name", "noitavania")
    elseif ModIsEnabled("biome-plus") then
        GlobalsSetValue("map_name", "alternate-biomes")
    elseif ModIsEnabled("Alternate Biomes") then
        GlobalsSetValue("map_name", "alternate-biomes")
    else
        GlobalsSetValue("map_name", "regular-main-branch")
        return map_name
    end
end

function launch_browser()
    if ModSettingGet("noitamap.PLAY_MAP_OPENING_SOUND") == true then
        GamePlaySound("mods/noitamap/files/audio/noitamap.bank", "create", 0, 0)
    end
    win32_open(full_url_string)
end

function OnPlayerSpawned(player_entity)
    GamePlaySound("mods/noitamap/files/audio/noitamap.bank",
                  "noitamap/dummy_sound", 0, 0)
    -- launch_browser()

    SetTimeOut(1.0, "mods/noitamap/scripts/debug_print_url.lua", "print_url")

    launch_browser()
    -- win32_open("https://nollagames.com")
end

-- used to detect settings changes
-- wiki: OnModSettingsChanged "Note: This callback doesn't appear to work. Modders have resorted to using OnPausedChanged instead to detect potential settings changes."
function OnPausedChanged(is_paused, is_inventory_paused)
    if not ModSettingGet("noita-together.NT_NO_STAT_PROGRESS") and
        GameHasFlagRun("NT_option_disable_progress") then
        -- nt print_error("Removing no_progress flags, option disabled")
        SetProgressDisable(false)
    elseif ModSettingGet("noita-together.NT_NO_STAT_PROGRESS") and
        not GameHasFlagRun("NT_option_disable_progress") then
        -- nt print_error("Addding no_progress flags, option enabled")
        SetProgressDisable(true)
    end
end

function OnModSettingsChanged() end

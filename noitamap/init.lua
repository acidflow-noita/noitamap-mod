-- TODO: Uncomment when the PR to Streamer Wands mod is merged
-- If the Streamer Wands mod is enabled, then do nothing at all, thanks Dexter
-- if ModIsEnabled("streamer_wands") or ModIsEnabled("Streamer Wands") then return end
dofile("data/scripts/game_helpers.lua")
dofile_once("data/scripts/lib/utilities.lua")
dofile_once("data/scripts/lib/coroutines.lua")
dofile_once("data/scripts/debug/keycodes.lua")
dofile("data/scripts/lib/mod_settings.lua")

-- Register custom audio bank
ModRegisterAudioEventMappings("mods/noitamap/files/audio/GUIDs.txt")

-- "Play" empty sound so the custom soundbank sounds work
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

function play_voiceline()
    local is_voiceline_enabled =
        ModSettingGet("noitamap.PLAY_MAP_OPENING_SOUND")
    local play_spicy_sound = ModSettingGet("noitamap.PLAY_SPICY_SOUND")
    if is_voiceline_enabled then
        local sound_path = "noitamap/what"
        if play_spicy_sound then sound_path = "noitamap/where" end
        GamePlaySound("mods/noitmap/files/audio/noitmap.bank", sound_path,
                      get_player_or_camera_pos())
    end
end

-- Getting player entity, should work even the player is polymorphed, thanks Dexter
function get_player()
    local player = EntityGetWithTag("player_unit")[1] or
                       EntityGetWithTag("polymorphed_player")[1] or nil
    if player ~= nil then return player end
end

-- Fallback to getting camera coordinates in case the player died
function get_current_camera_pos()
    local cam_x, cam_y = GameGetCameraPos()
    cam_x = tostring(math.floor(cam_x))
    cam_y = tostring(math.floor(cam_y))
    return cam_x, cam_y
end

-- Current in-game coordinates
function get_player_or_camera_pos()
    local ourPlayer = get_player()
    local pos_x, pos_y = 0, 0
    if ourPlayer then
        pos_x, pos_y = EntityGetTransform(ourPlayer)
    else
        pos_x, pos_y = get_current_camera_pos()
    end
    return pos_x, pos_y
end

-- Using mod detection to open the correct map
function get_map_url_param()
    -- new game detection, thanks Horscht
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

-- Building URL to pass to the browser opening function
function construct_url()
    local x_coord_url_param, y_coord_url_param = get_player_or_camera_pos()
    x_coord_url_param = tostring(math.floor(x_coord_url_param))
    y_coord_url_param = tostring(math.floor(y_coord_url_param))
    -- Arbitrary map zoom level which mimics in-game viewport
    local zoom_param = "930"
    local map_param = get_map_url_param()
    local url_protocol = "https://"
    -- Get the base URL from settings, default to "noitamap.com" if not provided
    local base_url = ModSettingGet("noitamap.MAP_WEBSITE")
    if base_url == "" then base_url = "noitamap.com" end

    -- Construct the full URL with the parameters
    local full_url_string = url_protocol .. base_url .. "/?x=" ..
                                x_coord_url_param .. "&y=" .. y_coord_url_param ..
                                "&zoom=" .. zoom_param .. "&map=" .. map_param
    return full_url_string
end

function OnPlayerSpawned(player_entity)
    -- "Play" empty sound so the custom soundbank sounds work
    GamePlaySound("mods/noitamap/files/audio/noitamap.bank",
                  "noitamap/dummy_sound", 0, 0)
end

-- Handling enabled mod settings and the map open command
function OnWorldPostUpdate()
    if InputIsKeyJustDown(16) and ModSettingGet("noitamap.MAP_OPENING_ENABLED") ==
        true then
        if ModSettingGet("noitamap.PLAY_MAP_OPENING_SOUND") == true then
            async(function()
                play_voiceline()
                wait(70)
                launch_browser()
            end)
        else
            launch_browser()
        end
        -- Detecting if M has been pressed on the keyboard
    elseif InputIsKeyJustDown(16) and
        ModSettingGet("noitamap.PLAY_MAP_OPENING_SOUND") == true then
        play_voiceline()
    end
    -- Debug: show full URL on screen if N has been pressed
    -- if InputIsKeyJustDown(17) then GamePrintImportant(construct_url()) end
end

-- Required to have async() working
function OnWorldPreUpdate() wake_up_waiting_threads(1) end

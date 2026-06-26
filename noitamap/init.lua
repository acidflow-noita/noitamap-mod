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

-- Candidate exe paths to try per browser preference. We try short names
-- first (resolved via Windows App Paths registry / PATH); if that fails
-- we fall through to common install locations. This catches things like
-- Firefox Developer Edition / Nightly, which don't register firefox.exe
-- in App Paths. Paths are built from env vars so non-C-drive Windows
-- installs and per-user (LOCALAPPDATA) installs are picked up. The final
-- fallback in open_url is the OS URL handler.
local PF = os.getenv("ProgramFiles") or "C:\\Program Files"
local PFX86 = os.getenv("ProgramFiles(x86)") or "C:\\Program Files (x86)"
local LA = os.getenv("LOCALAPPDATA") or ""

local BROWSER_PATHS = {
    chrome = {"chrome.exe", PF .. "\\Google\\Chrome\\Application\\chrome.exe",
              PFX86 .. "\\Google\\Chrome\\Application\\chrome.exe", LA .. "\\Google\\Chrome\\Application\\chrome.exe"},
    brave = {"brave.exe", PF .. "\\BraveSoftware\\Brave-Browser\\Application\\brave.exe",
             PFX86 .. "\\BraveSoftware\\Brave-Browser\\Application\\brave.exe",
             LA .. "\\BraveSoftware\\Brave-Browser\\Application\\brave.exe"},
    msedge = {"msedge.exe", PFX86 .. "\\Microsoft\\Edge\\Application\\msedge.exe",
              PF .. "\\Microsoft\\Edge\\Application\\msedge.exe"},
    firefox = {"firefox.exe", PF .. "\\Mozilla Firefox\\firefox.exe", PFX86 .. "\\Mozilla Firefox\\firefox.exe",
               PF .. "\\Firefox Developer Edition\\firefox.exe", PF .. "\\Firefox Nightly\\firefox.exe"}
}

function get_browser_candidates()
    local pref = ModSettingGet("noitamap.BROWSER")
    if pref == nil or pref == "" or pref == "default" then
        return nil
    end
    if pref == "custom" then
        local custom = ModSettingGet("noitamap.BROWSER_CUSTOM_PATH")
        if custom == nil or custom == "" then
            return nil
        end
        return {custom}
    end
    return BROWSER_PATHS[pref]
end

function open_url(url)
    local SHOWNORMAL = 1
    local candidates = get_browser_candidates()
    if candidates ~= nil then
        for _, exe in ipairs(candidates) do
            local hinst = shell32.ShellExecuteA(nil, "open", exe, url, nil, SHOWNORMAL)
            local code = tonumber(ffi.cast("intptr_t", hinst))
            if code > 32 then
                return
            end
        end
        -- every candidate failed - fall through to OS URL handler so the
        -- map still opens (Proton/Wine path; or a Windows machine without
        -- the chosen browser installed).
    end
    shell32.ShellExecuteA(nil, "open", url, nil, nil, SHOWNORMAL)
end

function launch_browser()
    local currentMapPos = construct_url()
    open_url(currentMapPos)
end

function play_voiceline()
    local is_voiceline_enabled = ModSettingGet("noitamap.PLAY_MAP_OPENING_SOUND")
    local play_spicy_sound = ModSettingGet("noitamap.PLAY_SPICY_SOUND")
    if is_voiceline_enabled then
        local sound_path = "noitamap/what"
        if play_spicy_sound then
            sound_path = "noitamap/where"
        end
        GamePlaySound("mods/noitmap/files/audio/noitmap.bank", sound_path, get_player_or_camera_pos())
    end
end

-- Getting player entity, should work even the player is polymorphed, thanks Dexter
function get_player()
    local player = EntityGetWithTag("player_unit")[1] or EntityGetWithTag("polymorphed_player")[1] or nil
    if player ~= nil then
        return player
    end
end

-- Fallback to getting camera coordinates in case the player died
function get_current_camera_pos()
    local cam_x, cam_y = GameGetCameraPos()
    cam_x = math.floor(cam_x)
    cam_y = math.floor(cam_y)
    return cam_x, cam_y
end

-- Determine in which // world the player is
function get_current_pw()
    local ourPlayer = get_player()
    local pos_x, pos_y = 0, 0
    if ourPlayer then
        pos_x, pos_y = EntityGetTransform(ourPlayer)
    else
        pos_x, pos_y = get_current_camera_pos()
    end
    local pw = GetParallelWorldPosition(pos_x, pos_y)
    return pw
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

-- Canonical ordered list of telescope unlock keys.
-- Order MUST match the JS side (noitamap/src/unlocks.ts UNLOCK_KEYS).
local UNLOCK_KEYS = {"sea_lava", "crumbling_earth", "cloud_thunder", "nuke", "bomb_holy", "necromancy",
                     "material_cement", "firework", "exploding_deer", "spiral_shot", "tentacle", "sea_mimic",
                     "touch_grass", "cessation", "piss", "kantele", "ocarina", "musicbox", "alchemy", "everything",
                     "divide", "bomb_holy_giga", "nukegiga", "mestari", "duplicate", "pyramid", "dragon", "rain",
                     "polymorph", "paint", "maths", "funky", "fish", "homing_wand", "black_hole", "rainbow_trail",
                     "destruction"}

-- base64url alphabet
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

-- Collect unlocks from persistent flags and encode as base64url bitfield.
function get_unlocks_param()
    -- Build byte array from bitfield
    local byte_count = math.ceil(#UNLOCK_KEYS / 8)
    local bytes = {}
    for i = 1, byte_count do
        bytes[i] = 0
    end

    for i, key in ipairs(UNLOCK_KEYS) do
        local flag = "card_unlocked_" .. key
        if HasFlagPersistent(flag) then
            local byte_idx = math.floor((i - 1) / 8) + 1
            local bit_pos = (i - 1) % 8
            bytes[byte_idx] = bytes[byte_idx] + (2 ^ bit_pos)
        end
    end

    -- base64url encode (no padding)
    local result = {}
    local i = 1
    while i <= #bytes do
        local b1 = bytes[i] or 0
        local b2 = bytes[i + 1] or 0
        local b3 = bytes[i + 2] or 0

        local n = b1 * 65536 + b2 * 256 + b3

        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64

        result[#result + 1] = B64:sub(c1 + 1, c1 + 1)
        result[#result + 1] = B64:sub(c2 + 1, c2 + 1)

        if i + 1 <= #bytes then
            result[#result + 1] = B64:sub(c3 + 1, c3 + 1)
        end
        if i + 2 <= #bytes then
            result[#result + 1] = B64:sub(c4 + 1, c4 + 1)
        end

        i = i + 3
    end

    return table.concat(result)
end

-- Achievement-pillar flags (data/scripts/biomes/mountain_tree.lua spawn_pillars,
-- read from persistent/flags). SEPARATE channel from get_unlocks_param: that one
-- (&u=) is the spell-availability set used for map generation; this one (&p=)
-- is the player's real achievement-pillar completion so the map renders unlocked
-- segments in colour and locked ones desaturated.
--
-- Order here is irrelevant: both sides sort alphabetically before packing, so
-- bit positions match noitamap/src/pillars-unlocks.ts PILLAR_FLAG_ORDER. When
-- the flag set changes, update BOTH lists and bump PILLAR_UNLOCK_VERSION on BOTH
-- sides (a stale &p= with a mismatched version prefix is ignored by the map).
local PILLAR_UNLOCK_VERSION = "1"
local PILLAR_FLAGS = {"misc_chest_rain", "misc_util_rain", "misc_worm_rain", "misc_greed_rain", "misc_altar_tablet",
                      "misc_mimic_potion_rain", "misc_monk_bots", "misc_sun_effect", "misc_darksun_effect",
                      "secret_tower", "player_status_ghostly", "player_status_ratty", "player_status_funky",
                      "player_status_lukky", "player_status_halo", "essence_fire", "essence_water", "essence_laser",
                      "essence_air", "essence_alcohol", "secret_moon", "secret_moon2", "special_mood", "secret_dmoon",
                      "dead_mood", "secret_sun_collision", "secret_darksun_collision", "progress_ending0",
                      "progress_ending1_toxic", "progress_ending1_gold", "progress_ending2",
                      "progress_newgameplusplus3", "progress_nightmare", "miniboss_dragon", "miniboss_limbs",
                      "miniboss_meat", "miniboss_ghost", "miniboss_pit", "miniboss_alchemist", "miniboss_robot",
                      "miniboss_wizard", "miniboss_maggot", "miniboss_fish", "miniboss_islandspirit",
                      "miniboss_threelk", "miniboss_gate_monsters", "final_secret_orb3", "miniboss_sky",
                      "boss_centipede", "progress_orb_1", "progress_orb_evil", "progress_orb_all", "progress_pacifist",
                      "progress_nogold", "progress_clock", "progress_minit", "progress_nohit", "progress_sun",
                      "progress_darksun", "progress_sunkill", "secret_supernova", "secret_greed", "final_secret_orb",
                      "final_secret_orb2", "secret_chest_dark", "secret_chest_light", "card_unlocked_everything",
                      "card_unlocked_divide", "secret_fruit", "secret_allessences", "secret_meditation",
                      "secret_buried_eye", "secret_hourglass", "progress_hut_a", "progress_hut_b", "secret_null"}

-- Collect set pillar flags and encode as "<version>.<base64url bitfield>".
function get_pillar_flags_param()
    -- Sort a copy so bit order matches the JS side regardless of list order.
    local keys = {}
    for _, f in ipairs(PILLAR_FLAGS) do
        keys[#keys + 1] = f
    end
    table.sort(keys)

    local byte_count = math.ceil(#keys / 8)
    local bytes = {}
    for i = 1, byte_count do
        bytes[i] = 0
    end

    for i, key in ipairs(keys) do
        if HasFlagPersistent(key) then
            local byte_idx = math.floor((i - 1) / 8) + 1
            local bit_pos = (i - 1) % 8
            bytes[byte_idx] = bytes[byte_idx] + (2 ^ bit_pos)
        end
    end

    -- base64url encode (no padding) -- identical scheme to get_unlocks_param
    local result = {}
    local i = 1
    while i <= #bytes do
        local b1 = bytes[i] or 0
        local b2 = bytes[i + 1] or 0
        local b3 = bytes[i + 2] or 0

        local n = b1 * 65536 + b2 * 256 + b3

        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64

        result[#result + 1] = B64:sub(c1 + 1, c1 + 1)
        result[#result + 1] = B64:sub(c2 + 1, c2 + 1)

        if i + 1 <= #bytes then
            result[#result + 1] = B64:sub(c3 + 1, c3 + 1)
        end
        if i + 2 <= #bytes then
            result[#result + 1] = B64:sub(c4 + 1, c4 + 1)
        end

        i = i + 3
    end

    return PILLAR_UNLOCK_VERSION .. "." .. table.concat(result)
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
        -- Regular run: use dynamic map so seeds are rendered live
        return "dynamic-main-branch"
    end
end

-- Building URL to pass to the browser opening function
function construct_url()
    local pos_x, pos_y = 0, 0
    pos_x, pos_y = get_player_or_camera_pos()

    -- Determine the current PW index
    local pw = get_current_pw()

    -- Define offsets for different mods
    local PW_OFFSET = 35840 -- Default offset
    if ModIsEnabled("Apotheosis") or ModIsEnabled("apotheosis") or ModIsEnabled("Noitavania") or
        ModIsEnabled("noitavania") then
        PW_OFFSET = 51200
    end

    -- Clamp the PW index to ±1
    if pw == -1 or pw == 1 or pw == 0 then
        new_pw = 0
    end
    if pw < -1 then
        new_pw = pw + 1
    end
    if pw > 1 then
        new_pw = pw - 1
    end

    -- Adjust the x-coordinate to stay within clamped PWs
    local clamped_x = pos_x - (new_pw * PW_OFFSET)

    -- Construct URL parameters
    local x_coord_url_param = tostring(math.floor(clamped_x))
    local y_coord_url_param = tostring(math.floor(pos_y))
    local zoom_param = "930"
    local map_param = get_map_url_param()

    -- Get the base URL from settings, default to "noitamap.com" if not provided
    local base_url = ModSettingGet("noitamap.MAP_WEBSITE")
    if base_url == nil or base_url == "" then
        base_url = "noitamap.com"
    end
    local url_protocol = "https://"
    if base_url:find("localhost") then
        url_protocol = "http://"
    end

    -- Construct the full URL with the parameters (short param names for dynamic map compat)
    local full_url_string = url_protocol .. base_url .. "/?x=" .. x_coord_url_param .. "&y=" .. y_coord_url_param ..
                                "&z=" .. zoom_param .. "&m=" .. map_param .. "&src=mod"

    -- Append seed param for dynamic map so the website renders the correct world
    if map_param == "dynamic-main-branch" and current_world_seed ~= nil then
        full_url_string = full_url_string .. "&se=" .. tostring(current_world_seed)
        -- Append encoded unlock state so the map generates with correct spell availability
        full_url_string = full_url_string .. "&u=" .. get_unlocks_param()
        -- Append achievement-pillar flags so the map renders the player's real pillar completion
        full_url_string = full_url_string .. "&p=" .. get_pillar_flags_param()
    end

    return full_url_string
end

function OnPlayerSpawned(player_entity)
    -- Capture the world seed so we can pass it to the map URL
    current_world_seed = tonumber(StatsGetValue("world_seed"))

    -- "Play" empty sound so the custom soundbank sounds work
    GamePlaySound("mods/noitamap/files/audio/noitamap.bank", "noitamap/dummy_sound", 0, 0)
end

-- Handling enabled mod settings and the map open command
function OnWorldPostUpdate()
    if not InputIsKeyJustDown(16) then
        return
    end

    local map_enabled = ModSettingGet("noitamap.MAP_OPENING_ENABLED")
    local sound_enabled = ModSettingGet("noitamap.PLAY_MAP_OPENING_SOUND")

    -- Default to true when settings haven't been initialized yet
    if map_enabled == nil then
        map_enabled = true
    end
    if sound_enabled == nil then
        sound_enabled = true
    end

    if map_enabled then
        if sound_enabled then
            async(function()
                play_voiceline()
                wait(70)
                launch_browser()
            end)
        else
            launch_browser()
        end
    elseif sound_enabled then
        play_voiceline()
    end
    -- Debug: show full URL on screen if N has been pressed
    -- if InputIsKeyJustDown(17) then
    --     GamePrintImportant(tostring(construct_url()))
    -- end
    -- Debug: show current PW
    -- if InputIsKeyJustDown(18) then
    --     GamePrintImportant(tostring(get_current_pw()))
    -- end
end

-- Required to have async() working
function OnWorldPreUpdate()
    wake_up_waiting_threads(1)
end

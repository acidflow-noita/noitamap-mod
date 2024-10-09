dofile("data/scripts/lib/mod_settings.lua")

local mod_id = "noitamap"
mod_settings_version = 2
mod_settings = {
    {
        id = "MAP_OPENING_ENABLED",
        ui_name = "Open the map website when you press M on the keyboard",
        value_default = true,
        scope = MOD_SETTING_SCOPE_RUNTIME
    }, {
        id = "PLAY_MAP_OPENING_SOUND",
        ui_name = "Play sound when you press M on the keyboard to open the map website",
        value_default = true,
        scope = MOD_SETTING_SCOPE_RUNTIME
    }, {
        id = "MAP_WEBSITE",
        ui_name = "Map website",
        ui_description = "Website to open",
        value_default = "https://noitamap.com",
        scope = MOD_SETTING_SCOPE_RUNTIME
    }
}
function ModSettingsUpdate(init_scope)
    local old_version = mod_settings_get_version(mod_id) -- This can be used to migrate some settings between mod versions.
    mod_settings_update(mod_id, mod_settings, init_scope)
end
function ModSettingsGuiCount()
    return mod_settings_gui_count(mod_id, mod_settings)
end

function ModSettingsGui(gui, in_main_menu)
    mod_settings_gui(mod_id, mod_settings, gui, in_main_menu)
end

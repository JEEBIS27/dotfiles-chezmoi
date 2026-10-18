local wezterm = require("wezterm")
local M = {}

function M.apply_to_config(config)
  local current = wezterm.home_dir .. "/.local/state/omarchy/current"
  local path = current .. "/theme/wezterm.toml"
  local file = io.open(path, "r")
  if file then
    file:close()
    -- Watch the stable parent too: Omarchy replaces the theme directory.
    wezterm.add_to_config_reload_watch_list(current)
    wezterm.add_to_config_reload_watch_list(path)
  else
    -- Portable snapshot for Windows/hosts without an Omarchy installation.
    path = wezterm.config_dir .. "/omarchy.toml"
    wezterm.add_to_config_reload_watch_list(path)
  end
  config.colors = wezterm.color.load_scheme(path)
end

function M.colors_for_config(config)
  return config.colors or {}
end

return M

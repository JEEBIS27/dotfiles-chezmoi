local wezterm = require("wezterm")
local config = wezterm.config_builder()
local theme = require("theme")

local is_windows = wezterm.target_triple:find("windows", 1, true) ~= nil

-- マウスを無効化
config.disable_default_mouse_bindings = false

config.automatically_reload_config = true
config.font = wezterm.font("HackGen35 Console NF", { weight = "Bold" })
config.font_size = 14.0
config.window_padding = { left = 14, right = 14, top = 14, bottom = 14 }
config.default_cursor_style = "SteadyBlock"
config.hide_mouse_cursor_when_typing = true
config.inactive_pane_hsb = { saturation = 1.0, brightness = 0.8 }
-- Match Ghostty: copy selections to the clipboard as well as PRIMARY.
config.mouse_bindings = {
  { event = { Up = { streak = 1, button = "Left" } }, mods = "NONE",
    action = wezterm.action.CompleteSelectionOrOpenLinkAtMouseCursor("ClipboardAndPrimarySelection") },
}
config.use_ime = true
config.window_background_opacity = 1.0
-- 背景画像を有効化
-- config.background = background
if is_windows then
  config.win32_system_backdrop = "Tabbed"
end
theme.apply_to_config(config)
-- 保持する行数
config.scrollback_lines = 3500

-- スクロールを有効化
config.enable_scroll_bar = true
config.mouse_wheel_scrolls_tabs = true
config.window_close_confirmation = "NeverPrompt"
-- Linux uses its local shell. Windows prefers Ubuntu, then another installed WSL distro.
if is_windows then
  local domains = wezterm.default_wsl_domains()
  if domains[1] then
    config.default_domain = domains[1].name
  end
  for _, domain in ipairs(domains) do
    if domain.name == "WSL:Ubuntu" then
      config.default_domain = domain.name
      break
    end
  end
end
local mux = wezterm.mux
wezterm.on("gui-startup", function(cmd)
  local tab, pane, window = mux.spawn_window(cmd or {})
  -- Let Hyprland place tiled windows; startup maximize would defeat splits.
  if not (wezterm.target_triple:find("linux", 1, true) and os.getenv("WAYLAND_DISPLAY")) then
    window:gui_window():maximize()
  end
end)
----------------------------------------------------
-- Tab
----------------------------------------------------
-- タイトルバーを非表示
-- Wayland RESIZE can draw an unwanted CSD titlebar; Hyprland handles resizing.
local is_linux_wayland = wezterm.target_triple:find("linux", 1, true)
  and os.getenv("WAYLAND_DISPLAY") ~= nil
config.window_decorations = is_linux_wayland and "NONE" or "RESIZE"
-- タブバーの表示
config.show_tabs_in_tab_bar = true
config.tab_max_width = 36
-- タブが一つの時は非表示
config.hide_tab_bar_if_only_one_tab = true
-- falseにするとタブバーの透過が効かなくなる
-- config.use_fancy_tab_bar = false

-- タブバーの透過
config.window_frame = {
  inactive_titlebar_bg = "none",
  active_titlebar_bg = "none",
}
-- タブバーを背景色に合わせる

-- タブの追加ボタンを非表示
config.show_new_tab_button_in_tab_bar = false

-- タブの閉じるボタンを非表示
config.show_close_tab_button_in_tabs = false

-- タブ同士の境界線を非表示
-- Colors, including tabs, are supplied by Omarchy.

-- タブの形をカスタマイズ
-- タブの左側の装飾
local SOLID_LEFT_ARROW = wezterm.nerdfonts.ple_lower_right_triangle
-- タブの右側の装飾
local SOLID_RIGHT_ARROW = wezterm.nerdfonts.ple_upper_left_triangle

local tab_labels = require("tabs")

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
  local current_colors = theme.colors_for_config(config)
  local tab_bar = current_colors.tab_bar or {}
  local inactive_tab = tab_bar.inactive_tab or {}
  local active_tab = tab_bar.active_tab or {}
  local active_bg = active_tab.bg_color or current_colors.cursor_bg
  local background = inactive_tab.bg_color or current_colors.background
  local foreground = inactive_tab.fg_color or current_colors.foreground
  local edge_background = "none"
  if tab.is_active then
    background = active_bg
    foreground = active_tab.fg_color or current_colors.background
  end
  local edge_foreground = background
  local width = math.max(1, math.min(max_width - 4, 36))
  local title = " " .. wezterm.truncate_right(tab_labels.label(tab), width) .. " "
  return {
    { Background = { Color = edge_background } },
    { Foreground = { Color = edge_foreground } },
    { Text = SOLID_LEFT_ARROW },
    { Background = { Color = background } },
    { Foreground = { Color = foreground } },
    { Text = title },
    { Background = { Color = edge_background } },
    { Foreground = { Color = edge_foreground } },
    { Text = SOLID_RIGHT_ARROW },
  }
end)

-- Remove color overrides left by the retired per-window theme selector.
wezterm.on("window-config-reloaded", function(window)
  local overrides = window:get_config_overrides() or {}
  if overrides.color_scheme or overrides.window_background_gradient then
    overrides.color_scheme = nil
    overrides.window_background_gradient = nil
    window:set_config_overrides(overrides)
  end
end)

----------------------------------------------------
-- keybinds
----------------------------------------------------
config.disable_default_key_bindings = true
config.keys = require("keybinds").keys
config.key_tables = require("keybinds").key_tables
config.enable_kitty_keyboard = true

return config

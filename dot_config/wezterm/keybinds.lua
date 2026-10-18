local wezterm = require("wezterm")
local act = wezterm.action

local is_windows = wezterm.target_triple:find("windows", 1, true) ~= nil

-- Store opacity per window and preserve theme/other runtime overrides.
local opacity_states = {
  { opacity = 1.0, backdrop = "Tabbed" },
  { opacity = 0.75, backdrop = "Acrylic" },
  { opacity = 0.5, backdrop = "Disable" },
}
local opacity_before_transparent = {}
local function toggle_opacity(window, transparent)
  local overrides = window:get_config_overrides() or {}
  local opacity = window:effective_config().window_background_opacity
  local current = opacity <= 0.5 and 3 or (opacity < 1 and 2 or 1)
  local id = window:window_id()
  local next_index
  if transparent then
    if current == 3 then
      next_index = opacity_before_transparent[id] or 1
    else
      opacity_before_transparent[id] = current
      next_index = 3
    end
  else
    next_index = current == 1 and 2 or 1
    opacity_before_transparent[id] = next_index
  end
  local state = opacity_states[next_index]
  overrides.window_background_opacity = state.opacity
  if is_windows then overrides.win32_system_backdrop = state.backdrop end
  window:set_config_overrides(overrides)
end


local select_exchange
local keys = {}
local M = "CTRL|ALT"
local function bind(key, mods, action)
  keys[#keys + 1] = { key = key, mods = mods, action = action }
end
local function prompt(description, callback)
  return act.PromptInputLine({ description = description,
    action = wezterm.action_callback(function(window, pane, text)
      if text and text ~= "" then callback(window, pane, text) end
    end) })
end
local rename_workspace = prompt("Rename workspace:", function(_, _, text)
  wezterm.mux.rename_workspace(wezterm.mux.get_active_workspace(), text)
end)
local new_workspace = prompt("New workspace:", function(window, pane, text)
  window:perform_action(act.SwitchToWorkspace({ name = text }), pane)
end)
local rename_tab = prompt("Rename tab:", function(_, pane, text)
  pane:tab():set_title(text)
end)
local function tool(args)
  return wezterm.action_callback(function(window, pane)
    if is_windows and not pane:get_domain_name():match("^WSL:") then
      window:toast_notification("WezTerm", "Use a Linux/WSL pane for this command.", nil, 3000)
      return
    end
    window:perform_action(act.SplitPane({ direction = "Right", size = { Percent = 33 },
      command = { args = args, domain = "CurrentPaneDomain" } }), pane)
  end)
end
bind("Insert", "CTRL", act.CopyTo("Clipboard"))
bind("Insert", "SHIFT", act.PasteFrom("Clipboard"))
-- Preserve the conventional clipboard aliases and TUI Shift+Enter.
bind("c", "CTRL|SHIFT", act.CopyTo("Clipboard"))
bind("v", "CTRL|SHIFT", act.PasteFrom("Clipboard"))
bind("Enter", "SHIFT", act.SendString("\x1b[13;2u"))
for _, item in ipairs({
  { "h", "LeftArrow", "Left" }, { "j", "DownArrow", "Down" },
  { "k", "UpArrow", "Up" }, { "l", "RightArrow", "Right" },
}) do
  for _, key in ipairs({ item[1], item[2] }) do
    bind(key, M, act.ActivatePaneDirection(item[3]))
    bind(key, M .. "|SHIFT", act.AdjustPaneSize({ item[3], 5 }))
  end
end
bind("Enter", M, act.SplitHorizontal({ domain = "CurrentPaneDomain" }))
bind("Enter", M .. "|SHIFT", act.SplitVertical({ domain = "CurrentPaneDomain" }))
bind("f", M .. "|SHIFT", act.TogglePaneZoomState)
bind("w", M, act.CloseCurrentPane({ confirm = true }))
bind("w", M .. "|SHIFT", act.CloseCurrentTab({ confirm = true }))
bind("n", M, act.SpawnCommandInNewTab({ domain = "CurrentPaneDomain" }))
bind("r", M, rename_tab)
bind("Tab", M, act.ActivateTabRelative(1))
bind("Tab", M .. "|SHIFT", act.ActivateTabRelative(-1))
bind("PageUp", M, act.ActivateTabRelative(-1))
bind("PageDown", M, act.ActivateTabRelative(1))
bind("PageUp", M .. "|SHIFT", act.SwitchWorkspaceRelative(-1))
bind("PageDown", M .. "|SHIFT", act.SwitchWorkspaceRelative(1))
for i = 1, 9 do bind(tostring(i), M, act.ActivateTab(i - 1)) end
bind("g", M, act.ShowLauncherArgs({ flags = "WORKSPACES", title = "Workspaces" }))
bind("g", M .. "|SHIFT", new_workspace)
bind("r", M .. "|SHIFT", rename_workspace)
bind("n", M .. "|SHIFT", act.SpawnWindow)
bind("e", M, wezterm.action_callback(function(window, pane) select_exchange(window, pane) end))
bind("f", M, act.Search({ CaseInSensitiveString = "" }))
bind("y", M .. "|SHIFT", act.ActivateCopyMode)
bind("y", M, tool({ "zsh", "-i", "-c", "y" }))
bind("p", M, act.ActivateCommandPalette)
bind(",", M, act.ReloadConfiguration)
bind(",", M .. "|SHIFT", wezterm.action_callback(function() wezterm.open_with(wezterm.config_file) end))
bind("=", M, act.IncreaseFontSize)
bind("-", M, act.DecreaseFontSize)
bind("0", M, act.ResetFontSize)
bind("u", M, wezterm.action_callback(function(window) toggle_opacity(window, false) end))
bind("u", M .. "|SHIFT", wezterm.action_callback(function(window) toggle_opacity(window, true) end))
bind("i", M, tool({ "herdr" }))
bind("i", M .. "|SHIFT", tool({ "zsh", "-i", "-c", "chat" }))
-- Herdr does not match all legacy Alt-BackTab packets; normalize to Alt-F9.
bind("Tab", "ALT|SHIFT", act.SendKey({ key = "F9", mods = "ALT" }))
-- Shared Alt layer: Herdr and tmux use the same Page key adapters.
for _, item in ipairs({ { "PageUp", "F5", "ALT" }, { "PageDown", "F6", "ALT" },
  { "PageUp", "F7", "ALT|SHIFT" }, { "PageDown", "F8", "ALT|SHIFT" } }) do
  bind(item[1], item[3], act.SendKey({ key = item[2], mods = "ALT" }))
end
-- Search opens the multiplexer copy mode and its native search prompt.
local function copy_screen_ready(pane)
  local text = pane:get_lines_as_text() or ""
  -- Herdr draws its COPY hint at the bottom; tmux has our COPY status at top.
  return text:find("COPY  h/j/k/l", 1, true) ~= nil
    or (text:match("^[^\n]*") or ""):match("COPY%s") ~= nil
end
bind("f", "ALT", wezterm.action_callback(function(window, pane)
  if copy_screen_ready(pane) then window:perform_action(act.SendString("/"), pane); return end
  window:perform_action(act.SendKey({ key = "y", mods = "ALT|SHIFT" }), pane)
  local attempts = 0
  local function start_search()
    attempts = attempts + 1
    if copy_screen_ready(pane) then
      window:perform_action(act.SendString("/"), pane)
    elseif attempts < 40 then
      wezterm.time.call_after(0.05, start_search)
    else
      window:toast_notification("Search", "Copy mode not ready; press / after it opens.", nil, 3000)
    end
  end
  wezterm.time.call_after(0.05, start_search)
end))
-- Scrollback is explicit; plain Shift+PageUp/Down belongs to inner applications.
bind("Home", M, act.ScrollToTop)
bind("End", M, act.ScrollToBottom)
-- Give adjacent panes their Vim direction as a native selection label.
-- The actual second key is handled by PaneSelect, not sent to the shell.
select_exchange = function(window, pane)
  local tab = pane:tab()
  if not tab then return end
  local labels = {}
  for _, item in ipairs({ { "h", "Left" }, { "j", "Down" }, { "k", "Up" }, { "l", "Right" } }) do
    local target = tab:get_pane_direction(item[2])
    if target and target:pane_id() ~= pane:pane_id() then labels[target:pane_id()] = item[1] end
  end
  local alphabet, extra = "", "1234567890abcdefgimnopqrstuvwxyz"
  for i, info in ipairs(tab:panes_with_info()) do
    local label = labels[info.pane:pane_id()] or extra:sub(i, i)
    if label == "" then return end
    alphabet = alphabet .. label
  end
  if #alphabet > 1 then
    window:perform_action(act.PaneSelect({ mode = "SwapWithActiveKeepFocus", alphabet = alphabet }), pane)
  end
end
return { keys = keys, key_tables = {
    copy_mode = {
      -- 移動
      { key = "LeftArrow",  mods = "NONE", action = act.CopyMode("MoveLeft") },
      { key = "DownArrow",  mods = "NONE", action = act.CopyMode("MoveDown") },
      { key = "UpArrow",    mods = "NONE", action = act.CopyMode("MoveUp") },
      { key = "RightArrow", mods = "NONE", action = act.CopyMode("MoveRight") },
      { key = "h", mods = "NONE", action = act.CopyMode("MoveLeft") },
      { key = "j", mods = "NONE", action = act.CopyMode("MoveDown") },
      { key = "k", mods = "NONE", action = act.CopyMode("MoveUp") },
      { key = "l", mods = "NONE", action = act.CopyMode("MoveRight") },
      -- 最初と最後に移動
      { key = "^",    mods = "NONE", action = act.CopyMode("MoveToStartOfLineContent") },
      { key = "$",    mods = "NONE", action = act.CopyMode("MoveToEndOfLineContent") },
      { key = "Home", mods = "NONE", action = act.CopyMode("MoveToStartOfLineContent") },
      { key = "End",  mods = "NONE", action = act.CopyMode("MoveToEndOfLineContent") },
      -- 左端に移動
      { key = "0", mods = "NONE", action = act.CopyMode("MoveToStartOfLine") },
      { key = "o", mods = "NONE", action = act.CopyMode("MoveToSelectionOtherEnd") },
      { key = "O", mods = "NONE", action = act.CopyMode("MoveToSelectionOtherEndHoriz") },
      --
      { key = ";", mods = "NONE", action = act.CopyMode("JumpAgain") },
      -- 単語ごと移動
      { key = "w", mods = "NONE", action = act.CopyMode("MoveForwardWord") },
      { key = "b", mods = "NONE", action = act.CopyMode("MoveBackwardWord") },
      { key = "e", mods = "NONE", action = act.CopyMode("MoveForwardWordEnd") },
      -- ジャンプ機能 t f
      { key = "t", mods = "NONE", action = act.CopyMode({ JumpForward = { prev_char = true } }) },
      { key = "f", mods = "NONE", action = act.CopyMode({ JumpForward = { prev_char = false } }) },
      { key = "T", mods = "NONE", action = act.CopyMode({ JumpBackward = { prev_char = true } }) },
      { key = "F", mods = "NONE", action = act.CopyMode({ JumpBackward = { prev_char = false } }) },
      -- 一番下へ
      { key = "G",    mods = "NONE", action = act.CopyMode("MoveToScrollbackBottom") },
      { key = "End",  mods = "CTRL", action = act.CopyMode("MoveToScrollbackBottom") },
      -- 一番上へ
      { key = "g",    mods = "NONE", action = act.CopyMode("MoveToScrollbackTop") },
      { key = "Home", mods = "CTRL", action = act.CopyMode("MoveToScrollbackTop") },
      -- viweport
      { key = "H", mods = "NONE", action = act.CopyMode("MoveToViewportTop") },
      { key = "L", mods = "NONE", action = act.CopyMode("MoveToViewportBottom") },
      { key = "M", mods = "NONE", action = act.CopyMode("MoveToViewportMiddle") },
      -- スクロール
      { key = "b",      mods = "CTRL", action = act.CopyMode("PageUp") },
      { key = "f",      mods = "CTRL", action = act.CopyMode("PageDown") },
      { key = "PageUp", mods = "NONE", action = act.CopyMode("PageUp") },
      { key = "PageDown", mods = "NONE", action = act.CopyMode("PageDown") },
      { key = "d", mods = "CTRL", action = act.CopyMode({ MoveByPage = 0.5 }) },
      { key = "u", mods = "CTRL", action = act.CopyMode({ MoveByPage = -0.5 }) },
      -- 範囲選択モード
      { key = "v", mods = "NONE", action = act.CopyMode({ SetSelectionMode = "Cell" }) },
      { key = "v", mods = "CTRL", action = act.CopyMode({ SetSelectionMode = "Block" }) },
      { key = "V", mods = "NONE", action = act.CopyMode({ SetSelectionMode = "Line" }) },
      -- コピー
      { key = "y", mods = "NONE", action = act.CopyTo("Clipboard") },

      -- コピーモードを終了
      {
        key = "Enter",
        mods = "NONE",
        action = act.Multiple({ { CopyTo = "ClipboardAndPrimarySelection" }, { CopyMode = "Close" } }),
      },
      { key = "Escape", mods = "NONE", action = act.CopyMode("Close") },
      { key = "c", mods = "CTRL", action = act.CopyMode("Close") },
      { key = "q", mods = "NONE", action = act.CopyMode("Close") },
    },
  },
}

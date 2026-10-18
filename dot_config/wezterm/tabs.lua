local wezterm = require("wezterm")
local nf = wezterm.nerdfonts
local M = {}

local function normalize(path)
  local value = (path or ""):gsub("\\", "/"):gsub("/+$", "")
  return value
end

local function basename(path)
  return normalize(path):match("([^/]+)$") or "/"
end

local function cwd_path(cwd)
  if not cwd then return "" end
  if type(cwd) ~= "string" then return cwd.file_path or "" end
  return cwd:gsub("^file://[^/]*", ""):gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end)
end

-- Read XDG paths once, without running shell commands in the tab renderer.
local home = normalize(wezterm.home_dir)
local folder_icons = {
  DOWNLOAD = nf.md_download, DOCUMENTS = nf.md_file_document,
  PICTURES = nf.md_image, MUSIC = nf.md_music, VIDEOS = nf.md_video,
  DESKTOP = nf.md_monitor, PROJECTS = nf.md_code_braces,
}
local special_paths = {}
local defaults = { DOWNLOAD = "Downloads", DOCUMENTS = "Documents", PICTURES = "Pictures",
  MUSIC = "Music", VIDEOS = "Videos", DESKTOP = "Desktop", PROJECTS = "Projects" }
for name, dir in pairs(defaults) do special_paths[home .. "/" .. dir] = folder_icons[name] end
local config_home = os.getenv("XDG_CONFIG_HOME") or (wezterm.home_dir .. "/.config")
local file = io.open(config_home .. "/user-dirs.dirs", "r")
if file then
  for line in file:lines() do
    local name, path = line:match('^XDG_(%u+)_DIR="(.-)"$')
    if name and folder_icons[name] then
      path = normalize(path:gsub("%$HOME", function() return wezterm.home_dir end))
      if path ~= home then special_paths[path] = folder_icons[name] end
    end
  end
  file:close()
end

local shells = { zsh = true, bash = true, sh = true, fish = true, nu = true,
  pwsh = true, powershell = true, cmd = true, wsl = true, ["wslhost"] = true }
local app_icons = {
  nvim = nf.custom_neovim, vim = nf.dev_vim, yazi = nf.md_folder_search,
  lazygit = nf.dev_git, git = nf.dev_git, ssh = nf.md_server_network,
  btop = nf.md_chart_areaspline, htop = nf.md_chart_areaspline,
  python = nf.dev_python, python3 = nf.dev_python, node = nf.dev_nodejs_small,
}

local function clean(text)
  return (text or ""):gsub("%c", " ")
end

function M.directory(path)
  path = normalize(path)
  if path == "" then return nil end
  -- Windows-hosted WSL reports the Linux home, not the Windows home_dir.
  if path == home or path:match("^/home/[^/]+$") or path == "/root" then
    return nf.md_home
  end
  if special_paths[path] then return special_paths[path] end
  local wsl_home, folder = path:match("^(/home/[^/]+)/([^/]+)$")
  if wsl_home then
    for name, dir in pairs(defaults) do
      if folder == dir then return folder_icons[name] end
    end
  end
  return nf.md_folder .. " " .. clean(basename(path))
end

function M.label(tab)
  local pane = tab.active_pane
  local path = cwd_path(pane.current_working_dir)
  local location = M.directory(path)
  local process = pane.foreground_process_name or ""
  process = process ~= "" and basename(process):lower():gsub("%.exe$", "") or ""
  local label
  if tab.tab_title and tab.tab_title ~= "" then
    label = nf.md_tag .. " " .. clean(tab.tab_title)
  elseif process == "nvim" and pane.user_vars and pane.user_vars.NVIM_TAB_LABEL
      and pane.user_vars.NVIM_TAB_LABEL ~= "" then
    label = clean(pane.user_vars.NVIM_TAB_LABEL)
  elseif process ~= "" and not shells[process] then
    label = (app_icons[process] or nf.cod_terminal) .. " " .. clean(process)
  elseif location then
    label = location
  else
    label = nf.cod_terminal .. " " .. clean(pane.title ~= "" and pane.title or "Terminal")
  end
  return label
end

-- Publish the local foreground application to the bar. The prefix is only
-- emitted from process metadata; filenames and arbitrary pane titles never
-- decide the application identity. Unknown programs keep their normal title.
-- Herdr is an Agent workspace and is always represented as Codex.
local bar_apps = { nvim = "Neovim", yazi = "Yazi", codex = "Codex", herdr = "Codex" }
wezterm.on("format-window-title", function(tab, pane)
  local active = tab.active_pane or pane
  local process = basename(active.foreground_process_name or ""):lower():gsub("%.exe$", "")
  local app = bar_apps[process]
  local title = clean(active.title or "")
  if app then
    return app .. " · WezTerm" .. (title ~= "" and " — " .. title or "")
  end
  return title ~= "" and "WezTerm — " .. title or "WezTerm"
end)

return M

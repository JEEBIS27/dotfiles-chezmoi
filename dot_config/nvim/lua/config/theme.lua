local M = {}
local path = vim.fn.expand("~/.local/state/omarchy/current/theme/palette.lua")
local last_content

local function reload()
  local file = io.open(path, "r")
  if not file then return end -- Non-Omarchy hosts keep Neovim's default colors.
  local content = file:read("*a")
  file:close()
  if content == last_content then return end
  local chunk, err = loadstring(content, "@" .. path)
  if not chunk then error(err) end
  local c = chunk()
  vim.g.omarchy_palette = c
  vim.o.background = c.mode == "light" and "light" or "dark"
  local term = {}
  for i = 0, 15 do term[i + 1] = c["color" .. i] end
  -- Kanagawa supplies highlight definitions only; every color comes from Omarchy.
  require("kanagawa").setup({
    compile = false,
    transparent = true,
    terminalColors = true,
    colors = { theme = { all = {
      ui = {
        fg = c.foreground, fg_dim = c.dark_foreground, fg_reverse = c.background,
        bg = c.background, bg_dim = c.dark_background, bg_gutter = c.background,
        bg_m3 = c.darker_background, bg_m2 = c.dark_background, bg_m1 = c.dark_background,
        bg_p1 = c.lighter_background, bg_p2 = c.lighter_background,
        special = c.accent, nontext = c.muted, whitespace = c.muted,
        bg_search = c.accent, bg_visual = c.selection_background,
        pmenu = { fg = c.foreground, fg_sel = c.selection_foreground,
          bg = c.dark_background, bg_sel = c.selection_background,
          bg_sbar = c.dark_background, bg_thumb = c.muted },
        float = { fg = c.foreground, bg = c.dark_background,
          fg_border = c.accent, bg_border = c.dark_background },
      },
      syn = {
        string = c.green, variable = c.foreground, number = c.orange,
        constant = c.orange, identifier = c.yellow, parameter = c.light_foreground,
        fun = c.blue, statement = c.magenta, keyword = c.magenta,
        operator = c.cyan, preproc = c.red, type = c.cyan, regex = c.yellow,
        deprecated = c.muted, comment = c.dark_foreground, punct = c.foreground,
        special1 = c.cyan, special2 = c.orange, special3 = c.red,
      },
      diag = { error = c.red, warning = c.yellow, info = c.blue, hint = c.cyan, ok = c.green },
      vcs = { added = c.green, removed = c.red, changed = c.yellow },
      diff = { add = c.lighter_background, delete = c.lighter_background,
        change = c.dark_background, text = c.selection_background },
      term = term,
    } } },
    overrides = function()
      return {
        Normal = { fg = c.foreground, bg = "none" },
        NormalNC = { fg = c.foreground, bg = "none" },
        NormalFloat = { fg = c.foreground, bg = "none" },
        FloatBorder = { fg = c.accent, bg = "none" },
        SignColumn = { bg = "none" }, EndOfBuffer = { bg = "none" },
        DiffAdd = { fg = c.green }, DiffDelete = { fg = c.red },
        DiffChange = { fg = c.yellow },
      }
    end,
  })
  vim.cmd.colorscheme("kanagawa")
  last_content = content
end

function M.setup()
  local function refresh()
    local ok, err = pcall(reload)
    if not ok then vim.notify("Omarchy theme: " .. tostring(err), vim.log.levels.ERROR) end
  end
  refresh()
  local group = vim.api.nvim_create_augroup("OmarchyTheme", { clear = true })
  vim.api.nvim_create_autocmd({ "FocusGained", "VimResume" }, { group = group, nested = true, callback = refresh })
  -- Poll the path, not its inode: Omarchy replaces the entire theme directory.
  M.timer = assert(vim.uv.new_timer())
  M.timer:start(1000, 1000, vim.schedule_wrap(refresh))
  vim.api.nvim_create_autocmd("VimLeavePre", { group = group, once = true, callback = function()
    M.timer:stop()
    M.timer:close()
  end })
end

return M

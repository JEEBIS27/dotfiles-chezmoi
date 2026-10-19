-- Ctrl owns application layout; Super/Ctrl+Alt/Alt belong to outer layers.
local function map(modes, lhs, fn, desc)
  vim.keymap.set(modes, lhs, fn, { desc = desc, silent = true })
end
local function normal_action(fn)
  return function()
    local mode = vim.api.nvim_get_mode().mode
    local insert = mode:sub(1, 1) == "i"
    if insert then vim.cmd.stopinsert() end
    if mode:sub(1, 1) == "t" then
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "nx", false)
    end
    fn()
    if insert and vim.bo.buftype == "" then vim.cmd.startinsert() end
  end
end
local function focus_window(direction)
  if vim.bo.filetype == "toggleterm" and vim.api.nvim_win_get_config(0).relative ~= "" then
    -- Directional commands leave a float for its origin before navigating splits.
    local origin = require("toggleterm.ui").get_origin_window()
    if origin and vim.api.nvim_win_is_valid(origin) then vim.api.nvim_set_current_win(origin) end
  end
  vim.cmd.wincmd(direction)
end
local modes = { "n", "i", "x", "t" }
for _, item in ipairs({ { "h", "Left", "h" }, { "j", "Down", "j" },
  { "k", "Up", "k" }, { "l", "Right", "l" } }) do
  for _, key in ipairs({ item[1], item[2] }) do
    map(modes, "<C-" .. key .. ">", normal_action(function() focus_window(item[3]) end), "Layout: focus " .. item[3])
    local resize = { h = "vertical resize -3", l = "vertical resize +3", j = "resize -2", k = "resize +2" }
    map(modes, "<C-S-" .. key .. ">", normal_action(function() vim.cmd(resize[item[3]]) end), "Layout: resize " .. item[3])
  end
end
map(modes, "<C-CR>", normal_action(function() vim.cmd("rightbelow vsplit") end), "Layout: split right")
map(modes, "<C-S-CR>", normal_action(function() vim.cmd("rightbelow split") end), "Layout: split down")
map(modes, "<C-w>", normal_action(function() vim.cmd.quit() end), "Layout: close window")
map(modes, "<C-S-w>", normal_action(function() if vim.fn.tabpagenr("$") > 1 then vim.cmd.tabclose() else vim.cmd.qall() end end), "Layout: close tab")
local function zoom()
  if vim.t.unified_zoom then
    local restore = vim.t.unified_zoom
    vim.t.unified_zoom = nil
    vim.cmd(restore)
  else
    vim.t.unified_zoom = vim.fn.winrestcmd()
    vim.cmd("wincmd _")
    vim.cmd("wincmd |")
  end
end
map(modes, "<C-S-f>", normal_action(zoom), "Layout: zoom / restore")
map(modes, "<C-n>", normal_action(function() vim.cmd.enew() end), "Buffers: create")
map(modes, "<C-S-n>", normal_action(function() vim.cmd.tabnew() end), "Tabs: create")
map(modes, "<C-Tab>", normal_action(function() vim.cmd.tabnext() end), "Tabs: next tab page")
map(modes, "<C-S-Tab>", normal_action(function() vim.cmd.tabprevious() end), "Tabs: previous tab page")
map(modes, "<C-PageUp>", normal_action(function() vim.cmd.bprevious() end), "Tabs: previous")
map(modes, "<C-PageDown>", normal_action(function() vim.cmd.bnext() end), "Tabs: next")
map(modes, "<C-S-PageUp>", normal_action(function() vim.cmd.tabprevious() end), "Tabs: move left")
map(modes, "<C-S-PageDown>", normal_action(function() vim.cmd.tabnext() end), "Tabs: move right")
for i = 1, 9 do
  map(modes, "<C-" .. i .. ">", normal_action(function()
    if i <= vim.fn.tabpagenr("$") then vim.cmd("tabnext " .. i) end
  end), "Tabs: select " .. i)
end
map({ "n", "i", "x" }, "<C-f>", normal_action(function() Snacks.picker.smart() end), "Search: files")
map({ "n", "i", "x" }, "<C-g>", normal_action(function() Snacks.picker.grep() end), "Search: contents")
map(modes, "<C-y>", normal_action(function() vim.cmd.Yazi() end), "Files: Yazi")
map(modes, "<C-t>", function() vim.cmd.ToggleTerm() end, "Terminal: toggle float")
-- Read one direction without opening a picker or introducing a leader sequence.
map(modes, "<C-e>", normal_action(function()
  local origin = vim.api.nvim_get_current_win()
  vim.api.nvim_echo({ { "Exchange: h/j/k/l (Esc cancels)", "ModeMsg" } }, false, {})
  local key = vim.fn.getcharstr()
  local dirs = { h = "h", j = "j", k = "k", l = "l", ["<Left>"] = "h", ["<Down>"] = "j", ["<Up>"] = "k", ["<Right>"] = "l" }
  local dir = dirs[vim.fn.keytrans(key)]
  vim.api.nvim_echo({}, false, {})
  if not dir then return end
  local target = vim.fn.win_getid(vim.fn.winnr(dir))
  if target ~= origin then vim.api.nvim_win_call(origin, function() vim.cmd(tostring(vim.fn.win_id2win(target)) .. "wincmd x") end) end
end), "Layout: exchange direction")
-- Structural Ctrl+K wins even after a buffer-local LSP setup.
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(args.buf) then return end
      for _, mode in ipairs({ "n", "i" }) do pcall(vim.keymap.del, mode, "<C-k>", { buffer = args.buf }) end
    end)
  end,
})

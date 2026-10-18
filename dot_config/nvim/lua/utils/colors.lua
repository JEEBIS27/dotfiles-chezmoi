local M = {}

local function from_highlight(group, attribute)
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
  local value = ok and hl[attribute] or nil
  return value and string.format("#%06x", value) or nil
end

local function palette_from_highlights()
  local function pick(group, attribute, ...)
    local value = from_highlight(group, attribute)
    if value then return value end
    for i = 1, select("#", ...), 2 do
      value = from_highlight(select(i, ...), select(i + 1, ...))
      if value then return value end
    end
  end

  local c = vim.g.omarchy_palette
  local bg = c and c.background or pick("Normal", "bg", "NormalFloat", "bg", "Pmenu", "bg", "CursorLine", "bg")
  local fg = c and c.foreground or pick("Normal", "fg", "NormalFloat", "fg", "Comment", "fg")
  local red = c and c.red or pick("DiagnosticError", "fg", "Error", "fg", "WarningMsg", "fg")
  local yellow = c and c.yellow or pick("DiagnosticWarn", "fg", "WarningMsg", "fg", "Constant", "fg")
  local blue = c and c.blue or pick("DiagnosticInfo", "fg", "Identifier", "fg", "Type", "fg")
  local green = c and c.green or pick("String", "fg", "DiagnosticOk", "fg", "Function", "fg")
  local violet = c and c.magenta or pick("Special", "fg", "Statement", "fg", "Title", "fg")
  local muted = c and c.dark_foreground or pick("Comment", "fg", "LineNr", "fg", "NonText", "fg")
  local surface = c and c.lighter_background or pick("CursorLine", "bg", "Pmenu", "bg", "NormalFloat", "bg")

  return {
    waveBlue2 = blue,
    oniViolet = violet,
    springBlue = blue,
    springGreen = green,
    dragonRed = red,
    dragonOrange = yellow,
    dragonYellow = yellow,
    dragonBlue2 = blue,
    dragonViolet = violet,
    dragonWhite = fg,
    dragonGray = muted,
    dragonGray2 = muted,
    dragonGray3 = muted,
    dragonBlack0 = bg,
    dragonBlack2 = bg,
    dragonBlack3 = bg,
    dragonBlack4 = surface,
    dragonBlack5 = surface,
    sumiInk5 = muted,
    mauve = violet,
    red = red,
    peach = yellow,
    yellow = yellow,
    green = green,
    sky = blue,
    blue = blue,
    text = fg,
    overlay2 = muted,
    overlay1 = muted,
    overlay0 = muted,
    surface2 = surface,
    surface1 = surface,
    surface0 = surface,
    base = bg,
    mantle = bg,
    crust = bg,
  }
end

function M.refresh_palette()
  local palette = palette_from_highlights()
  M.palette = M.palette or {}
  for key in pairs(M.palette) do
    M.palette[key] = nil
  end
  for key, value in pairs(palette) do
    M.palette[key] = value
  end
  return M.palette
end

M.refresh_palette()

local palette_group = vim.api.nvim_create_augroup("UserThemePaletteRefresh", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", {
  group = palette_group,
  callback = function() M.refresh_palette() end,
  desc = "現在のThemeからカラーパレットを更新",
})

---@alias RGB { r: number, g: number, b: number }

---@param hex string Color value supplied by the active theme
---@return RGB
function M.hex_to_rgb(hex)
  hex = hex:gsub("^#", "")
  if #hex ~= 6 then error("Invalid theme color. Expected RGB value.") end
  return {
    r = tonumber(hex:sub(1, 2), 16),
    g = tonumber(hex:sub(3, 4), 16),
    b = tonumber(hex:sub(5, 6), 16),
  }
end

---@param color RGB
---@return string
function M.rgb_to_hex(color)
  local function component(value)
    return string.format("%02x", math.floor(value + 0.5))
  end
  return "#" .. component(color.r) .. component(color.g) .. component(color.b)
end

---@param foreground string Theme foreground color
---@param background string Theme background color
---@param alpha number Alpha value between 0 and 1
---@return string
function M.alpha_blend(foreground, background, alpha)
  if type(foreground) ~= "string" or type(background) ~= "string" then
    error("Theme foreground and background colors must be RGB values")
  end
  local fg, bg = M.hex_to_rgb(foreground), M.hex_to_rgb(background)
  alpha = math.max(0, math.min(1, alpha))
  return M.rgb_to_hex({
    r = fg.r * alpha + bg.r * (1 - alpha),
    g = fg.g * alpha + bg.g * (1 - alpha),
    b = fg.b * alpha + bg.b * (1 - alpha),
  })
end

return M

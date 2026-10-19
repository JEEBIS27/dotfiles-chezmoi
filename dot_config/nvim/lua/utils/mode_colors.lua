local colors = require("utils.colors")
local palette = colors.palette

local M = {
  colors = {},
  line_opacity = {
    normal = 0.78,
    copy = 0.4,
    delete = 0.4,
    insert = 0.4,
    visual = 0.45,
  },
}

function M.refresh()
  M.colors.normal = palette.muted or palette.blue
  M.colors.copy = palette.yellow
  M.colors.delete = palette.red
  M.colors.insert = palette.sky
  M.colors.visual = palette.oniViolet

  for scene, color in pairs(M.colors) do
    if color then
      vim.api.nvim_set_hl(0, "Modes" .. scene:sub(1, 1):upper() .. scene:sub(2), { bg = color })
    end
  end
end

function M.get_scene(mode, operator)
  if mode:sub(1, 2) == "no" and vim.v.operator ~= "" then
    operator = vim.v.operator
  end

  if operator == "d" or operator == "c" then
    return "delete"
  elseif operator == "r" then
    return "insert"
  elseif operator == "y" then
    return "copy"
  elseif mode:sub(1, 1) == "i" or mode:sub(1, 1) == "R" then
    return "insert"
  elseif mode:sub(1, 1) == "v" or mode:sub(1, 1) == "V" or mode:sub(1, 1) == "\22" then
    return "visual"
  end
  return "normal"
end

function M.background(scene)
  return colors.alpha_blend(M.colors[scene], palette.base, M.line_opacity[scene])
end

function M.modes_opts()
  return {
    -- Modes.nvim reads ModesCopy/ModesDelete/... highlights that refresh with Theme.
    colors = {},
    line_opacity = {
      copy = M.line_opacity.copy,
      delete = M.line_opacity.delete,
      insert = M.line_opacity.insert,
      visual = M.line_opacity.visual,
    },
  }
end

M.refresh()
local group = vim.api.nvim_create_augroup("UserModeThemeColors", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", {
  group = group,
  callback = M.refresh,
  desc = "モード色を現在のThemeから更新",
})

return M

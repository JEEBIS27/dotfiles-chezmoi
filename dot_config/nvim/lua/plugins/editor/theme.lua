return {
  {
    "rebelot/kanagawa.nvim",
    priority = 1000,
    lazy = false,
    config = function() require("config.theme").setup() end,
  },
}

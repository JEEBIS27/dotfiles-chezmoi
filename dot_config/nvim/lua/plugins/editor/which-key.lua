return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    delay = 300,
    spec = {
      { "<leader>c", group = "Code / Copilot" },
      { "<leader>g", group = "Git" },
      { "<leader>f", group = "Find / Files" },
      { "<leader>w", group = "Windows" },
      { "<leader>h", group = "Git hunk" },
      { "<leader>p", group = "Peek / Plugins" },
      { "<leader>u", group = "UI" },
    },
  },
}

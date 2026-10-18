return {   -- Snacks: ユーティリティライブラリ（ダッシュボード対応）
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    config = function()
      local Snacks = require("snacks")

      Snacks.setup({
        dashboard = {
          enabled = true,
          preset = {
            header = [[
 ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
 ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
 ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
 ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
 ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
 ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝
            ]],
            keys = {
              { icon = "󰘔 ", key = "n", desc = "New File", action = ":ene | startinsert" },
              { icon = "󰉋 ", key = "y", desc = "Yazi File Manager", action = ":Yazi" },
              { icon = "󰔟 ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
              { icon = "󰈙 ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
              { icon = "󰊄 ", key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
              { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy", enabled = package.loaded.lazy ~= nil },
              { icon = "󰗼 ", key = "q", desc = "Quit", action = ":qa" },
            },
          },
          sections = {
            { section = "header" },
            { section = "keys", gap = 1, padding = 1 },
            { section = "startup" },
          },
        },
        bigfile = { enabled = true },
        explorer = { enabled = false },
        indent = { enabled = true },
        input = { enabled = true },
        picker = {
            enabled = true,
            ui_select = true,
            layout = "default",
            sources = {
                files = {
                    hidden = true,
                },
                grep = {
                    hidden = true,
                    regex = "true",
                },
            },
            win = {
                input = {
                    keys = {
                        ["<Tab>"] = { "focus_preview", mode = { "n", "x" } },
                    },
                },
            },
            matcher = {
                frecency = true,
            },
        },
        notifier = { enabled = true },
        quickfile = { enabled = false },
        scope = { enabled = true },
        scroll = { enabled = true },
        statuscolumn = { enabled = false },
        words = { enabled = false },
        rename = { enabled = true },
      })
    end,
  }



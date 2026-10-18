return {

  {
    "rcarriga/nvim-notify",
    version = "*",
    lazy = true,
    init = function()
      require("utils.highlight").set_highlights("nvim-notify_hl", function()
        local palette = require("utils.colors").palette
        return {
          NotifyBackground = { bg = palette.base },
          NotifyERRORBorder = { bg = palette.base },
          NotifyERRORBody = { bg = palette.base },
          NotifyWARNBorder = { bg = palette.base },
          NotifyWARNBody = { bg = palette.base },
          NotifyINFOBorder = { bg = palette.base },
          NotifyINFOBody = { bg = palette.base },
          NotifyDEBUGBorder = { bg = palette.base },
          NotifyDEBUGBody = { bg = palette.base },
          NotifyTRACEBorder = { bg = palette.base },
          NotifyTRACEBody = { bg = palette.base },
        }
      end)
    end,
    opts = {
      render = "wrapped-compact",
      stages = "static",
      timeout = 3000,
      max_height = function()
        return math.floor(vim.o.lines * 0.75)
      end,
      max_width = function()
        return math.floor(vim.o.columns * 0.50)
      end,
    },
  },
  {
    "folke/noice.nvim",
    version = "*",
    event = { "VeryLazy" },
    dependencies = {
      "nui.nvim",
      "nvim-notify",
    },
    opts = {
      lsp = {
        -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true, -- requires hrsh7th/nvim-cmp
        },
        signature = { enabled = true },
        progress = { enabled = true },
        hover = { enabled = false }, -- use lspsaga
      },
      -- you can enable a preset for easier configuration
      presets = {
        bottom_search = false, -- use a classic bottom cmdline for search
        command_palette = true, -- position the cmdline and popupmenu together
        long_message_to_split = true, -- long messages will be sent to a split
        inc_rename = false, -- enables an input dialog for inc-rename.nvim
        lsp_doc_border = false, -- add a border to hover docs and signature help
      },
      routes = {
        {
          filter = { event = "notify", find = "No information available" },
          opts = { skip = true },
        },
      },
      messages = {
        view_search = false, -- use hlslens
      },
      views = {
        cmdline_popup = {
          position = { row = 6, col = "50%" },
          border = { style = "rounded", padding = { 0, 1 } },
          win_options = {
            winhighlight = { NormalFloat = "NoiceCmdlinePopupNormal", FloatBorder = "NoiceCmdlinePopupBorder" },
          },
        },
        cmdline_popupmenu = {
          position = { row = 6, col = "50%" },
          border = { style = "rounded", padding = { 0, 1 } },
          win_options = {
            winhighlight = { NormalFloat = "NoiceCmdlinePopupmenuNormal", FloatBorder = "NoiceCmdlinePopupmenuBorder" },
          },
        },
      },
    },
    init = function()
      require("utils.highlight").force_set_highlights("noice_hl", function()
        return {
          NoiceCmdline = { link = "NormalFloat" },
          NoiceCmdlinePrompt = { link = "Title" },
          NoiceCmdlineIcon = { link = "Special" },
          NoiceCmdlineIconCmdline = { link = "Special" },
          NoiceCmdlineIconSearch = { link = "Search" },
          NoiceCmdlineIconFilter = { link = "Search" },
          NoiceCmdlineIconLua = { link = "Type" },
          NoiceCmdlineIconHelp = { link = "Directory" },
          NoiceCmdlinePopupNormal = { link = "NormalFloat" },
          NoiceCmdlinePopupBorder = { link = "FloatBorder" },
          NoiceCmdlinePopupmenuNormal = { link = "Pmenu" },
          NoiceCmdlinePopupmenuBorder = { link = "FloatBorder" },
        }
      end)
    end,
  },
}

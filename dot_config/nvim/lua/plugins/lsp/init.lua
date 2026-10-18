return {
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    opts = function()
      local node_candidates = vim.fn.glob(vim.fn.expand("~/.nvm/versions/node/*/bin/node"), false, true)
      table.sort(node_candidates)
      return {
        copilot_node_command = node_candidates[#node_candidates] or "node",
        suggestion = {
          enabled = true,
          auto_trigger = true,
          hide_during_completion = false,
        },
        panel = { enabled = false },
      }
    end,
  },
  {
    "saghen/blink.cmp",
    build = 'cargo build --release',
    dependencies = {
      "saghen/blink.lib",
      "zbirenbaum/copilot.lua",
      "giuxtaposition/blink-cmp-copilot",
      "rafamadriz/friendly-snippets",
    },
    opts = {
      keymap = {
        preset = "default",
        -- Herdr reserves Ctrl+Space; standard insert-mode completion remains reachable.
        ["<C-x><C-o>"] = { "show", "show_documentation", "hide_documentation" },
        ["<Tab>"] = {
          function(cmp)
            if not require("utils.copilot").auto_trigger_enabled() then return false end

            local ok, suggestion = pcall(require, "copilot.suggestion")
            if ok and suggestion.is_visible() ~= nil then
              suggestion.accept()
              return true
            end

            if cmp.is_menu_visible() then
              for index, item in ipairs(cmp.get_items()) do
                if item.source_id == "copilot" then
                  return cmp.accept({ index = index })
                end
              end
            end
            return false
          end,
          "select_next",
          "snippet_forward",
          "fallback",
        },
        ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
      },
      completion = {
        list = {
          selection = {
            preselect = false,
          },
          cycle = {
            from_top = true,
          },
        },
        menu = {
          auto_show = true,
        },
        trigger = {
          show_on_insert = false,
        },
        ghost_text = {
          enabled = false,
          show_without_selection = true,
        },
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer", "copilot" },
        providers = {
          copilot = {
            name = "copilot",
            module = "blink-cmp-copilot",
            score_offset = 100,
            async = true,
            enabled = function()
              return require("utils.copilot").auto_trigger_enabled()
            end,
          },
        },
      },
    },
    opts_extend = { "sources.default" },
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufWritePre", "BufNewFile" },
    dependencies = { "saghen/blink.cmp" },
    init = function()
      require("utils.highlight").force_set_highlights("lspconfig_hl", function()
        local colors = require("utils.colors")
        local palette = colors.palette
        return {
          LspInlayHint = { link = "DiagnosticHint" },
          DiagnosticErrorLine = { bg = colors.alpha_blend(palette.red, palette.base, 0.15) },
          DiagnosticWarnLine = { bg = colors.alpha_blend(palette.peach, palette.base, 0.15) },
          DiagnosticHintLine = { bg = colors.alpha_blend(palette.green, palette.base, 0.15) },
          DiagnosticInfoLine = { bg = colors.alpha_blend(palette.blue, palette.base, 0.15) },
        }
      end)

      vim.diagnostic.config({
        virtual_text = true,
        severity_sort = true,
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "󰅚 ",
            [vim.diagnostic.severity.WARN] = "󰀪 ",
            [vim.diagnostic.severity.HINT] = "󰌶 ",
            [vim.diagnostic.severity.INFO] = " ",
          },
          linehl = {
            [vim.diagnostic.severity.ERROR] = "DiagnosticErrorLine",
            [vim.diagnostic.severity.WARN] = "DiagnosticWarnLine",
            [vim.diagnostic.severity.HINT] = "DiagnosticHintLine",
            [vim.diagnostic.severity.INFO] = "DiagnosticInfoLine",
          },
        },
      })
    end,
    config = function()
      local augroup = vim.api.nvim_create_augroup("neovim_lspconfig_setup", { clear = true })

      vim.api.nvim_create_autocmd("BufWritePre", {
        group = augroup,
        ---@param args { buf: integer }
        callback = function(args)
          require("plugins.lsp.config.lsp_actions_on_save")({ buf = args.buf })
        end,
      })

      vim.lsp.config("*", {
        on_attach = require("plugins.lsp.config.utils").on_attach_common,
        capabilities = require("blink.cmp").get_lsp_capabilities({
          textDocument = {
            foldingRange = {
              dynamicRegistration = false,
              lineFoldingOnly = true,
            },
          },
        }),
      })

      vim.lsp.enable({
        -- Go
        "gopls",
        -- "golangci_lint_ls",

        -- JavaScript
        "biome",
        -- "denols",
        "eslint",
        "prismals",
        "tailwindcss",
        "vtsls",
        "vue_ls",

        -- JSON (JSON Schema)
        "jsonls",
        "jsonnet_ls",
        "yamlls",

        -- Others
        "gh_actions_ls",
        "bashls",
        "buf_ls",
        "dockerls",
        "graphql",
        "lua_ls",
        "nixd",
        "pyright",
      })
    end,
  },
  {
    "stevearc/conform.nvim",
    version = "*",
    lazy = true,
    opts = {
      formatters = {
        shfmt = { append_args = { "-i", "2" } },
      },
      -- stylua: ignore
      formatters_by_ft = {
        javascript      = { "biome", "prettierd", stop_after_first = true },
        typescript      = { "biome", "prettierd", stop_after_first = true },
        javascriptreact = { "biome", "prettierd", stop_after_first = true },
        typescriptreact = { "biome", "prettierd", stop_after_first = true },
        json            = { "biome", "prettierd", stop_after_first = true },
        jsonc           = { "biome", "prettierd", stop_after_first = true },
        graphql         = { "biome", "prettierd", stop_after_first = true },
        lua             = { "stylua" },
        sh              = { "shfmt" },
        zsh             = { "shfmt" },
        nix             = { "nixfmt" },
      },
    },
  },
  {
    "nvimdev/lspsaga.nvim",
    dependencies = { "nvim-web-devicons", "nvim-treesitter" },
    event = { "LspAttach" },
    init = function()
      require("utils.highlight").set_highlights("lspsaga_hl", function()
        local palette = require("utils.colors").palette
        return {
          SagaNormal = { bg = palette.crust },
          SagaBorder = { bg = palette.crust },
        }
      end)
    end,
    opts = function()
      return {
        symbol_in_winbar = { enable = false },
        lightbulb = { enable = false },
        code_action = { show_server_name = true },
        ui = {
          -- create padding around the floating window
          border = { " ", " ", " ", " ", " ", " ", " ", " " },
        },
        scroll_preview = {
          scroll_down = "<Down>",
          scroll_up = "<Up>",
        },
      }
    end,
  },
  {
    "WilliamHsieh/overlook.nvim",
    opts = {},
    init = function()
      vim.api.nvim_create_autocmd("BufWinEnter", {
        group = vim.api.nvim_create_augroup("overlook_enter_mapping", { clear = true }),
        pattern = "*",
        callback = function()
          vim.schedule(function()
            if vim.w.is_overlook_popup then
              -- open in orig window on enter
              vim.keymap.set("n", "<CR>", function()
                require("overlook.api").open_in_original_window()
              end, { buffer = true, desc = "Overlook: Open in original window" })

              vim.keymap.set("n", "<C-S-CR>", function()
                require("overlook.api").open_in_split()
              end, { buffer = true, desc = "Overlook: Open below" })
              -- open in vsplit on ctrl+enter
              for _, lhs in ipairs({ "<C-CR>", ";" }) do
                vim.keymap.set("n", lhs, function()
                  require("overlook.api").open_in_vsplit()
                end, { buffer = true, desc = "Overlook: Open in vertical split" })
              end
            end
          end)
        end,
      })
    end,
    keys = {
      {
        "<leader>pu",
        function()
          require("overlook.api").restore_popup()
        end,
        { desc = "Restore last popup" },
      },
      {
        "<leader>pU",
        function()
          require("overlook.api").restore_all_popups()
        end,
        { desc = "Restore all popups" },
      },
      {
        "<leader>pc",
        function()
          require("overlook.api").close_all()
        end,
        { desc = "Close all popups" },
      },
      {
        "<leader>ps",
        function()
          require("overlook.api").open_in_split()
        end,
        { desc = "Open popup in split" },
      },
      {
        "<leader>pv",
        function()
          require("overlook.api").open_in_vsplit()
        end,
        { desc = "Open popup in vsplit" },
      },
      {
        "<leader>pt",
        function()
          require("overlook.api").open_in_tab()
        end,
        { desc = "Open popup in tab" },
      },
      {
        "<leader>po",
        function()
          require("overlook.api").open_in_original_window()
        end,
        { desc = "Open popup in current window" },
      },
    },
  },
}

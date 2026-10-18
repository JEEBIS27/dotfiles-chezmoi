return {

  -- UI改善プラグイン
  {
    "stevearc/dressing.nvim",
    opts = {},
  },

  -- UI コンポーネントライブラリ（snacks.nvim 等の依存）
  {
    "nvim-lua/plenary.nvim",
  },

  -- nvim-scrollbar: スクロールバーを表示
  {
    'petertriho/nvim-scrollbar',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {},
  },

  -- fidget.nvim: LSPの進捗状況をステータスラインに表示
  {
    'j-hui/fidget.nvim',
    event = 'LspAttach',
    opts = {},
  },
  -- hlchunk: インデントガイドとチャンクハイライト
  {
    "shellRaining/hlchunk.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("hlchunk").setup({
        chunk = {
          enable = true,
          notify = false,
          use_treesitter = false,
          exclude_filetypes = { toggleterm = true },
          chars = {
            horizontal_line = "─",
            vertical_line = "│",
            left_top = "╭",
            left_bottom = "╰",
            right_arrow = "─",
          },
          style = function()
            return { { fg = require("utils.colors").palette.oniViolet } }
          end,
          textobject = "",
          max_file_size = 1024 * 1024,
          error_sign = true,
        },
        indent = {
          enable = true,
          use_treesitter = false,
          exclude_filetypes = { toggleterm = true },
          chars = {
            "│",
          },
          style = function()
            return { { fg = require("utils.colors").palette.sumiInk5 } }
          end,
        },
        line_num = {
          enable = false,
          use_treesitter = false,
          style = function()
            return require("utils.colors").palette.oniViolet
          end,
        },
        blank = {
          enable = false,
        },
      })
    end,
  },

  -- nvim-scrollbar: スクロールバーを表示
  {
    'petertriho/nvim-scrollbar',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {},
  },

  -- fidget.nvim: LSPの進捗状況をステータスラインに表示
  {
    'j-hui/fidget.nvim',
    event = 'LspAttach',
    opts = {},
  },

  -- gitsigns.nvim: Gitの変更をサインカラムに表示
  {
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      signs = {
        add          = { text = '│' },
        change       = { text = '│' },
        delete       = { text = '_' },
        topdelete    = { text = '‾' },
        changedelete = { text = '~' },
      },
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns
        local opts = { buffer = bufnr, silent = true }
        vim.keymap.set('n', '<leader>N', gs.next_hunk,   vim.tbl_extend('force', opts, { desc = '次の変更へ' }))
        vim.keymap.set('n', '<leader>P', gs.prev_hunk,   vim.tbl_extend('force', opts, { desc = '前の変更へ' }))
        vim.keymap.set('n', '<leader>hs', gs.stage_hunk,   vim.tbl_extend('force', opts, { desc = 'hunkをステージ' }))
        vim.keymap.set('n', '<leader>hr', gs.reset_hunk,   vim.tbl_extend('force', opts, { desc = 'hunkをリセット' }))
        vim.keymap.set('n', '<leader>hp', gs.preview_hunk, vim.tbl_extend('force', opts, { desc = 'hunkをプレビュー' }))        vim.keymap.set('n', '<leader>ghb', gs.blame_line,   vim.tbl_extend('force', opts, { desc = '行のblame' }))
      end,
    },
  },

  -- modes.nvim: モードに応じてカーソルの色を変える
  {
    "mvllow/modes.nvim",
    version = "*",
    event = { "CursorMoved", "CursorMovedI" },
    opts = function()
      return require("utils.mode_colors").modes_opts()
    end,
  },

  -- vimade: 非フォーカスペインを暗く表示
  {
    "tadaa/vimade",
    version = "*",
    event = { "BufReadPre", "BufWritePre", "BufNewFile" },
    opts = function()
      return {
        fadelevel = 0.4,
        basebg = function()
          return require("utils.colors").palette.base
        end,
      }
    end,
  },
}

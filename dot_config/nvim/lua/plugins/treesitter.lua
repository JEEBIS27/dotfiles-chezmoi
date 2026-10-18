return {
  {
    "nvim-treesitter/nvim-treesitter",
    version = "*",
    build = ":TSUpdate",
    event = { "BufReadPre" },
    config = function()
      local parser_install_dir = vim.fn.stdpath("data") .. "/treesitter"
      vim.opt.runtimepath:prepend(parser_install_dir)
      local directive_opts = vim.fn.has("nvim-0.10") == 1 and { force = true, all = false } or true

      vim.treesitter.query.add_directive("downcase!", function(match, _, bufnr, pred, metadata)
        local capture_id = pred[2]
        local node = match[capture_id]
        if not node or not metadata then
          return
        end

        local ok, text = pcall(vim.treesitter.get_node_text, node, bufnr, {
          metadata = metadata[capture_id],
        })
        if not ok then
          return
        end

        metadata[capture_id] = metadata[capture_id] or {}
        metadata[capture_id].text = string.lower(text or "")
      end, directive_opts)

      require("nvim-treesitter.configs").setup({
        parser_install_dir = parser_install_dir,
        ensure_installed = {
          "bash",
          "css",
          "cue",
          -- 'diff',
          "dockerfile",
          "git_config",
          "git_rebase",
          "gitattributes",
          "gitcommit",
          "gitignore",
          "go",
          "gomod",
          "gosum",
          "gowork",
          "graphql",
          "hcl",
          "html",
          "javascript",
          "jq",
          "jsdoc",
          "json",
          "json5",
          "jsonnet",
          "lua",
          "make",
          "markdown",
          "markdown_inline", -- required by lspsaga.nvim
          "prisma",
          "proto",
          "python",
          "regex",
          "ruby",
          "rust",
          "scss",
          "sql",
          "starlark",
          "toml",
          "tsx",
          "typescript",
          "vim",
          "vue",
          "yaml",
        },
        -- indent = {
        --   enable = true,
        -- },
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
      })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter-context",
    event = { "BufReadPre" },
    dependencies = { "nvim-treesitter" },
    init = function()
      require("utils.highlight").force_set_highlights("treesitter-context_hl", function()
        return {
          TreesitterContext = { bg = require("utils.colors").palette.surface1, blend = 10 },
        }
      end)
    end,
    opts = {
      max_lines = 4,
    },
  },
  {
    'nvim-treesitter/nvim-treesitter-textobjects',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    config = function()
      require('nvim-treesitter-textobjects').setup({
        select = {
          lookahead = true,
        },
        move = {
          set_jumps = true,
        },
      })

      local select = require('nvim-treesitter-textobjects.select')
      local move = require('nvim-treesitter-textobjects.move')

      local function select_textobject(query)
        return function()
          select.select_textobject(query, 'textobjects')
        end
      end

      local function goto_next_start(query)
        return function()
          move.goto_next_start(query, 'textobjects')
        end
      end

      local function goto_previous_start(query)
        return function()
          move.goto_previous_start(query, 'textobjects')
        end
      end

      vim.keymap.set({ 'x', 'o' }, 'af', select_textobject('@function.outer'),    { desc = '関数全体' })
      vim.keymap.set({ 'x', 'o' }, 'if', select_textobject('@function.inner'),    { desc = '関数本体' })
      vim.keymap.set({ 'x', 'o' }, 'aa', select_textobject('@parameter.outer'),   { desc = '引数全体' })
      vim.keymap.set({ 'x', 'o' }, 'ia', select_textobject('@parameter.inner'),   { desc = '引数の中身' })
      vim.keymap.set({ 'x', 'o' }, 'ab', select_textobject('@block.outer'),       { desc = 'ブロック全体' })
      vim.keymap.set({ 'x', 'o' }, 'ib', select_textobject('@block.inner'),       { desc = 'ブロックの中身' })
      vim.keymap.set({ 'x', 'o' }, 'ac', select_textobject('@class.outer'),       { desc = 'クラス全体' })
      vim.keymap.set({ 'x', 'o' }, 'ic', select_textobject('@class.inner'),       { desc = 'クラス本体' })
      vim.keymap.set({ 'x', 'o' }, 'al', select_textobject('@loop.outer'),        { desc = 'ループ全体' })
      vim.keymap.set({ 'x', 'o' }, 'il', select_textobject('@loop.inner'),        { desc = 'ループ本体' })
      vim.keymap.set({ 'x', 'o' }, 'ai', select_textobject('@conditional.outer'), { desc = 'if / else など条件分岐全体' })
      vim.keymap.set({ 'x', 'o' }, 'ii', select_textobject('@conditional.inner'), { desc = '条件分岐の本体' })
      vim.keymap.set({ 'x', 'o' }, 'av', select_textobject('@call.outer'),        { desc = '関数呼び出し全体' })
      vim.keymap.set({ 'x', 'o' }, 'iv', select_textobject('@call.inner'),        { desc = '関数呼び出しの引数部分' })
      vim.keymap.set({ 'x', 'o' }, 'ar', select_textobject('@return.outer'),      { desc = 'return 文全体' })
      vim.keymap.set({ 'x', 'o' }, 'ir', select_textobject('@return.inner'),      { desc = 'return の返り値部分' })

      vim.keymap.set({ 'n', 'x', 'o' }, ']f', goto_next_start('@function.outer'),    { desc = '次の関数へ移動' })
      vim.keymap.set({ 'n', 'x', 'o' }, ']c', goto_next_start('@class.outer'),       { desc = '次のクラスへ移動' })
      vim.keymap.set({ 'n', 'x', 'o' }, ']l', goto_next_start('@loop.outer'),        { desc = '次のループへ移動' })
      vim.keymap.set({ 'n', 'x', 'o' }, ']i', goto_next_start('@conditional.outer'), { desc = '次の条件分岐へ移動' })
      vim.keymap.set({ 'n', 'x', 'o' }, '[f', goto_previous_start('@function.outer'),    { desc = '前の関数へ移動' })
      vim.keymap.set({ 'n', 'x', 'o' }, '[c', goto_previous_start('@class.outer'),       { desc = '前のクラスへ移動' })
      vim.keymap.set({ 'n', 'x', 'o' }, '[l', goto_previous_start('@loop.outer'),        { desc = '前のループへ移動' })
      vim.keymap.set({ 'n', 'x', 'o' }, '[i', goto_previous_start('@conditional.outer'), { desc = '前の条件分岐へ移動' })
    end,
  },
  {
    "haringsrob/nvim_context_vt",
    event = { "BufReadPre" },
    dependencies = { "nvim-treesitter" },
    init = function()
      require("utils.highlight").force_set_highlights("context_vt_hl", {
        ContextVt = { link = "DiagnosticHint" },
      })
    end,
    opts = {
      min_rows = 3,
    },
  },
  {
    "andymass/vim-matchup",
    version = "*",
    event = { "BufReadPre" },
    dependencies = { "nvim-treesitter" },
    config = function()
      vim.g.matchup_matchparen_offscreen = {}
    end,
  },
  {
    "windwp/nvim-ts-autotag",
    event = { "BufReadPre" },
    dependencies = { "nvim-treesitter" },
    opts = {
      opts = {
        enable_close = true,
        enable_rename = true,
        enable_close_on_slash = true,
      },
    },
  },
  {
    "JoosepAlviste/nvim-ts-context-commentstring",
    lazy = true,
    opts = { enable_autocmd = false },
  },
  -- mason.nvim: LSPサーバーのインストール管理
  {
    'williamboman/mason.nvim',
    build = ':MasonUpdate',
    opts = {},
  },
}

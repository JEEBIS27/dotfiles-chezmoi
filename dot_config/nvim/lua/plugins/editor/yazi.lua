return {
  {
    "mikavilpas/yazi.nvim",
    version = "*",
    event = "VeryLazy",
    dependencies = {
      { "nvim-lua/plenary.nvim", lazy = true },
    },
    opts = {
      -- Yazi本体のキー設定を維持し、Ctrl+Enterで右、Ctrl+Shift+Enterで下、Ctrl+NはYazi内のタブ作成に使う。
      keymaps = {
        show_help = false,
        open_file_in_vertical_split = "<C-Enter>",
        open_file_in_horizontal_split = "<C-S-Enter>",
        open_file_in_tab = false,
        grep_in_directory = false,
        replace_in_directory = false,
        cycle_open_buffers = false,
        copy_relative_path_to_selected_files = false,
        send_to_quickfix_list = false,
        change_working_directory = false,
        open_and_pick_window = false,
      },
      hooks = {
        on_yazi_ready = function(buffer)
          vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(buffer) then return end
          local pass = { "<C-h>", "<C-j>", "<C-k>", "<C-l>", "<C-Left>", "<C-Down>", "<C-Up>", "<C-Right>",
            "<C-S-h>", "<C-S-j>", "<C-S-k>", "<C-S-l>", "<C-S-Left>", "<C-S-Down>", "<C-S-Up>", "<C-S-Right>",
            "<C-n>", "<C-w>", "<C-S-w>", "<C-S-f>", "<C-y>", "<C-e>", "<C-PageUp>", "<C-PageDown>", "<C-S-PageUp>", "<C-S-PageDown>",
            "<C-f>", "<C-g>" }
          for i = 1, 9 do pass[#pass + 1] = "<C-" .. i .. ">" end
          for _, key in ipairs(pass) do
            vim.keymap.set("t", key, key, { buffer = buffer, remap = false, desc = "Yazi: app-layer input" })
          end
          end)
        end,
      },
      open_for_directories = true,
      change_neovim_cwd_on_close = false,
    },
    init = function()
      -- ディレクトリを開く処理をnetrwからYaziへ渡す。
      vim.g.loaded_netrwPlugin = 1
    end,
  },
}

-- ===================================
-- キーマッピング
-- ===================================

-- 保存と終了
vim.keymap.set('n', '<leader>uc', function()
  local ok, suggestion = pcall(require, 'copilot.suggestion')
  if not ok then return end

  suggestion.toggle_auto_trigger()
  local enabled = require('utils.copilot').auto_trigger_enabled()
  local cmp_ok, cmp = pcall(require, 'blink.cmp')
  if cmp_ok then
    if enabled then
      cmp.reload('copilot')
    else
      cmp.hide()
      cmp.reload('copilot')
    end
  end
  vim.notify((enabled and 'ON' or 'OFF') .. ' Copilot suggestion auto_trigger', vim.log.levels.INFO)
end, { desc = 'Copilot提案の自動表示をトグル' })
vim.keymap.set('n', '<C-s>', '<cmd>update<CR>', { desc = '保存' })  -- [ノーマル] ファイルを保存（変更があれば）
vim.keymap.set('i', '<C-s>', '<C-o><cmd>update<CR><Esc>', { desc = '保存' })  -- [挿入] ファイルを保存
vim.keymap.set('v', '<C-s>', '<Esc><cmd>update<CR>gv', { desc = '保存' })  -- [ビジュアル] ファイルを保存して選択を維持
vim.keymap.set('n', '<C-S-s>', '<cmd>update!<CR>', { desc = '保存' })  -- [ノーマル] ファイルを強制保存
vim.keymap.set('i', '<C-S-s>', '<C-o><cmd>update!<CR><Esc>', { desc = '保存' })  -- [挿入] ファイルを強制保存
vim.keymap.set('v', '<C-S-s>', '<Esc><cmd>update!<CR>gv', { desc = '保存' })  -- [ビジュアル] ファイルを強制保存して選択を維持
vim.keymap.set('n', '<C-n>', '<cmd>ene | startinsert<CR>', { desc = '新規ファイル作成' })  -- [ノーマル] ファイルを新規作成
vim.keymap.set('i', '<C-n>', '<Esc><cmd>ene | startinsert<CR>', { desc = '新規ファイル作成' })  -- [挿入] ファイルを新規作成
vim.keymap.set('v', '<C-n>', '<Esc><cmd>ene | startinsert<CR>', { desc = '新規ファイル作成' })  -- [ビジュアル] ファイルを新規作成

-- 単語選択
vim.keymap.set('v', 'v', 'V', { desc = '行選択' })  -- [ビジュアル] 行選択

-- 削除はブラックホールレジスタを使い、ペースト用レジスタを汚さない
vim.keymap.set('n', '<BS>', '"_X', { desc = '左方向に削除（レジスタに保存しない）' })
vim.keymap.set('v', '<BS>', '"_x', { desc = '削除（レジスタに保存しない）' })
vim.keymap.set({ 'n', 'v' }, 'x', '"_x', { desc = '削除（レジスタに保存しない）' })
vim.keymap.set({ 'n', 'v' }, '<Del>', '"_x', { desc = '削除（レジスタに保存しない）' })
vim.keymap.set('n', '<S-BS>', '"_d0', { desc = '行頭まで削除（レジスタに保存しない）' })
vim.keymap.set('n', '<S-Del>', '"_D', { desc = '行末まで削除（レジスタに保存しない）' })
vim.keymap.set('n', 'X', '"_D', { desc = '行末まで削除（レジスタに保存しない）' })

-- Yaziでカレントファイルのディレクトリを開く
vim.keymap.set("n", "-", "<CMD>Yazi<CR>", { desc = "Yaziでファイル一覧を開く" })

-- 検索ハイライトを消去
vim.keymap.set('n', '<Esc>', ':noh<CR>', { silent = true, desc = '検索ハイライトを消去' })  -- [ノーマル] 検索ハイライトを消去

-- PgUp/PgDn のスクロール量を半ページ（<C-u>/<C-d>相当）に変更
vim.keymap.set('n', '<PageUp>', '<C-u>', { desc = '半ページ上へスクロール' })
vim.keymap.set('n', '<PageDown>', '<C-d>', { desc = '半ページ下へスクロール' })
vim.keymap.set('n', '<S-PageUp>', '<C-b>', { desc = '1ページ上へスクロール' })

-- ウィンドウ移動

-- ウィンドウ入れ替え（番号指定）
-- 端末のペイン交換とは別にNeovimのウィンドウを交換する。

-- バッファ移動

-- TABで次のバッファ
vim.keymap.set('n', '<Tab>', '<cmd>bn<CR>', { desc = '次のバッファ' })  -- [ノーマル] 次のバッファへ切り替え
vim.keymap.set('n', '<S-Tab>', '<cmd>bp<CR>', { desc = '前のバッファ' })  -- [ノーマル] 前のバッファへ切り替え

-- Top Pickers & Explorer
vim.keymap.set('n', '<C-b>', function() Snacks.picker.buffers() end, { desc = "Buffers" } )
vim.keymap.set('n', '<C-g>', function() Snacks.picker.grep() end, { desc = "Grep" } )
-- git
vim.keymap.set('n', '<C-d>', function() Snacks.picker.git_diff() end, { desc = "Git Diff" } )

-- 行の移動（表示行単位）
vim.keymap.set('n', 'j', 'gj', { desc = '下へ移動（表示行）' })  -- [ノーマル] 表示行単位で下へ移動
vim.keymap.set('n', 'k', 'gk', { desc = '上へ移動（表示行）' })  -- [ノーマル] 表示行単位で上へ移動

-- 現在行を画面上から任意行（Noiceのcmdline_popup高さと合わせる）に配置
vim.keymap.set('n', 'zz', function()
  local target_row = 7
  local view = vim.fn.winsaveview()
  view.topline = math.max(1, view.lnum - (target_row - 1))
  vim.fn.winrestview(view)
end, { desc = '現在行を上から7行目に配置' })

-- インデント調整後も選択を維持
vim.keymap.set('v', '<', '<gv', { desc = 'インデントを減らす' })  -- [ビジュアル] インデントを減らして選択を維持
vim.keymap.set('v', '>', '>gv', { desc = 'インデントを増やす' })  -- [ビジュアル] インデントを増やして選択を維持

-- 選択したテキストを移動
vim.keymap.set('v', 'J', ":m '>+1<CR>gv=gv", { desc = '選択行を下に移動' })  -- [ビジュアル] 選択行を1行下へ移動
vim.keymap.set('v', 'K', ":m '<-2<CR>gv=gv", { desc = '選択行を上に移動' })  -- [ビジュアル] 選択行を1行上へ移動
vim.keymap.set('v', '<S-Down>', ":m '>+1<CR>gv=gv", { desc = '選択行を下に移動' })  -- [ビジュアル] 選択行を1行下へ移動
vim.keymap.set('v', '<S-Up>', ":m '<-2<CR>gv=gv", { desc = '選択行を上に移動' })  -- [ビジュアル] 選択行を1行上へ移動

-- Prefix aliases remain reachable inside Ghostty, WezTerm, and Herdr.
for key, direction in pairs({ h = 'h', j = 'j', k = 'k', l = 'l' }) do
  vim.keymap.set('n', '<leader>w' .. key, '<cmd>wincmd ' .. direction .. '<CR>', { desc = 'エディタのウィンドウへ移動' })
end
vim.keymap.set('n', '<leader>wv', '<cmd>vsplit<CR>', { desc = '右にウィンドウを分割' })
vim.keymap.set('n', '<leader>we', '<cmd>split<CR>', { desc = '下にウィンドウを分割' })
vim.keymap.set('n', '<leader>wx', '<cmd>wincmd x<CR>', { desc = 'ウィンドウを交換' })
vim.keymap.set('n', '<leader>wq', '<cmd>quit<CR>', { desc = 'ウィンドウを閉じる' })
vim.keymap.set('n', '<leader>ff', function() Snacks.picker.smart() end, { desc = 'ファイル検索' })
vim.keymap.set('n', '<leader>fr', function() Snacks.picker.recent() end, { desc = '最近のファイル' })
vim.keymap.set('n', '<leader>fg', function() Snacks.picker.grep() end, { desc = '文字列検索' })
vim.keymap.set('n', '<leader>fb', function() Snacks.picker.buffers() end, { desc = 'バッファ一覧' })
vim.keymap.set('n', '<leader>fe', function() vim.cmd.Yazi() end, { desc = 'Explorer' })
vim.keymap.set('n', '<leader>j', '<C-d>', { desc = '半ページ下へ' })
vim.keymap.set('n', '<leader>k', '<C-u>', { desc = '半ページ上へ' })
vim.keymap.set('n', '<leader>K', '<C-b>', { desc = '1ページ上へ' })

-- Structural shortcuts are shared with the terminal and Yazi.
require("config.unified_keys")
vim.keymap.set("n", "<leader>gl", function() Snacks.picker.git_log() end, { desc = "Git Log" })

-- ===================================
-- Neovim 基本設定
-- ===================================
vim.opt.updatetime = 250           -- 更新時間を短縮
-- -----------------------------------
-- 基本オプション
-- -----------------------------------
vim.cmd('syntax on')               -- シンタックスハイライトを有効化
vim.opt.number = true              -- 行番号を表示
vim.opt.relativenumber = true      -- 相対行番号を表示
vim.opt.signcolumn = 'no'          -- サインカラムは statuscolumn の %s で管理
-- vim.opt.mouse = ''                 -- マウスサポートを無効化
vim.opt.ignorecase = true          -- 検索時に大文字小文字を区別しない
vim.opt.smartcase = true           -- 大文字が含まれる場合は区別する
vim.opt.hlsearch = true            -- 検索結果をハイライト
vim.opt.incsearch = true           -- インクリメンタルサーチ
vim.opt.wrap = false                -- 行の折り返しをする
vim.opt.breakindent = true         -- 折り返し時にインデントを保持
vim.opt.cursorline = true          -- カーソル行をハイライト
vim.opt.guicursor = "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20"  -- カーソルの点滅を無効化
vim.opt.termguicolors = true       -- True Colorを有効化
vim.opt.signcolumn = 'no'          -- 左端のサインカラムは statuscolumn の %s で管理
vim.opt.timeoutlen = 300           -- キーマップのタイムアウト
vim.opt.splitright = true          -- 垂直分割時に右に開く
vim.opt.splitbelow = true          -- 水平分割時に下に開く
vim.opt.scrolloff = 8              -- スクロール時の余白行数
vim.opt.sidescrolloff = 8          -- 横スクロール時の余白

-- -----------------------------------
-- 見た目の設定
-- -----------------------------------
vim.opt.showmode = false           -- モード表示を非表示（ステータスラインで表示される場合）
vim.opt.showcmd = false            -- コマンド入力中の表示を無効化
vim.opt.cmdheight = 0              -- コマンドライン領域を隠す
vim.opt.laststatus = 0             -- 空のステータスラインを隠す
local function apply_stealth_statusline()
  local p = require("utils.colors").palette
  local bg = p.base
  vim.api.nvim_set_hl(0, "StatusLine", { fg = bg, bg = bg })
  vim.api.nvim_set_hl(0, "StatusLineNC", { fg = bg, bg = bg })
  vim.api.nvim_set_hl(0, "SignColumn", { bg = "none" })
  vim.api.nvim_set_hl(0, "LineNr", { fg = p.overlay0, bg = "none" })
  vim.api.nvim_set_hl(0, "CursorLineNr", { fg = p.blue, bg = "none" })
end

apply_stealth_statusline()
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = apply_stealth_statusline,
  desc = "現在テーマの背景にStatusLineを馴染ませる",
})

-- NeovimのTUIは端末のフォントを継承する。Ghostty側でHackGen35 Console NFを指定。

-- -----------------------------------
-- 文字コード・改行コード
-- -----------------------------------
vim.opt.encoding = 'utf-8'
vim.opt.fileencodings = 'utf-8,sjis,euc-jp,latin1'
vim.opt.fileformats = 'unix,dos,mac'

-- -----------------------------------
-- リーダーキーの設定
-- -----------------------------------
vim.g.mapleader = ' '              -- リーダーキーをスペースに設定
vim.g.maplocalleader = ' '

-- -----------------------------------
-- タブ・インデント設定
-- -----------------------------------
vim.opt.tabstop = 2                -- タブ文字の幅
vim.opt.shiftwidth = 2             -- インデント幅
vim.opt.expandtab = true           -- タブをスペースに展開
vim.opt.smartindent = true         -- スマートインデント
vim.opt.autoindent = true          -- 自動インデント

-- -----------------------------------
-- クリップボード設定
-- -----------------------------------
vim.opt.clipboard = 'unnamedplus'  -- システムクリップボードを使用

-- 利用可能なクリップボードツールを優先順に選択:
--   1. wl-clipboard (ネイティブWayland環境)
--   2. xsel        (X11環境・WSLg含む)
--   3. OSC 52      (SSH・tmux等ターミナル経由のフォールバック)
local function wayland_socket_exists()
  local display = vim.env.WAYLAND_DISPLAY
  if not display then return false end
  local socket = display:sub(1,1) == '/' and display
    or (vim.env.XDG_RUNTIME_DIR or '/run/user/1000') .. '/' .. display
  return vim.fn.executable('wl-copy') == 1 and vim.uv.fs_stat(socket) ~= nil
end

if wayland_socket_exists() then
  vim.g.clipboard = {
    name  = 'wl-clipboard',
    copy  = {
      ['+'] = { 'wl-copy', '--type', 'text/plain' },
      ['*'] = { 'wl-copy', '--primary', '--type', 'text/plain' },
    },
    paste = {
      ['+'] = { 'wl-paste', '--no-newline' },
      ['*'] = { 'wl-paste', '--no-newline', '--primary' },
    },
    cache_enabled = 0,
  }
elseif vim.fn.executable('xsel') == 1 then
  vim.g.clipboard = {
    name  = 'xsel',
    copy  = {
      ['+'] = { 'xsel', '--clipboard', '--input' },
      ['*'] = { 'xsel', '--primary',   '--input' },
    },
    paste = {
      ['+'] = { 'xsel', '--clipboard', '--output' },
      ['*'] = { 'xsel', '--primary',   '--output' },
    },
    cache_enabled = 1,
  }
elseif vim.fn.executable('powershell.exe') == 1 then
  vim.g.clipboard = {
    name = 'Windows clipboard',
    copy = {
      ['+'] = { 'clip.exe' },
      ['*'] = { 'clip.exe' },
    },
    paste = {
      ['+'] = { 'powershell.exe', '-NoLogo', '-NoProfile', '-Command', 'Get-Clipboard' },
      ['*'] = { 'powershell.exe', '-NoLogo', '-NoProfile', '-Command', 'Get-Clipboard' },
    },
    cache_enabled = 1,
  }
else
  local osc52 = require('vim.ui.clipboard.osc52')
  vim.g.clipboard = {
    name  = 'OSC 52',
    copy  = { ['+'] = osc52.copy('+'), ['*'] = osc52.copy('*') },
    paste = { ['+'] = osc52.paste('+'), ['*'] = osc52.paste('*') },
  }
end

-- -----------------------------------
-- バックアップ・スワップファイル
-- -----------------------------------
vim.opt.backup = false             -- バックアップファイルを作成しない
vim.opt.writebackup = false        -- 書き込み前のバックアップを作成しない
vim.opt.swapfile = false           -- スワップファイルを作成しない
vim.opt.undofile = true            -- アンドゥ履歴を永続化

-- ===================================
-- プラグインマネージャー (lazy.nvim)
-- ===================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- 行番号: 絶対番号を左揃え・相対番号を右揃えで別列に表示
vim.opt.numberwidth = 4

-- statuscol.nvimがNumber Lineを描画する。


-- ファイル保存時に末尾の空白を削除
vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = '*',
  callback = function()
    local save_cursor = vim.fn.getpos('.')
    vim.cmd([[%s/\s\+$//e]])
    vim.fn.setpos('.', save_cursor)
  end,
  desc = '保存時に末尾の空白を削除',
})

-- ヤンク時にハイライト
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function()
    vim.highlight.on_yank({ higroup = 'IncSearch', timeout = 200 })
  end,
  desc = 'ヤンク時にハイライト',
})

-- flash.nvim: f/t ジャンプ後に残るハイライトをカーソル移動後に即クリア
vim.api.nvim_create_autocmd('CursorMoved', {
  callback = function()
    vim.schedule(function()
      local ns = vim.api.nvim_get_namespaces()['flash']
      if ns then
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          pcall(vim.api.nvim_buf_clear_namespace, buf, ns, 0, -1)
        end
      end
    end)
  end,
  desc = 'flash.nvim のハイライトをジャンプ後にクリア',
})

-- 引数なし起動時にプラグイン更新をチェック
vim.api.nvim_create_autocmd('VimEnter', {
  callback = function()
    if vim.fn.argc() ~= 0 then
      return
    end

    local now = os.time()
    local interval = 24 * 60 * 60
    local state_file = vim.fn.stdpath('state') .. '/plugin-update-check.time'
    local last_check = 0

    if vim.uv.fs_stat(state_file) then
      local lines = vim.fn.readfile(state_file)
      last_check = tonumber(lines[1]) or 0
    end

    if (now - last_check) < interval then
      return
    end

    local ok_manage, manage = pcall(require, 'lazy.manage')
    if not ok_manage then
      return
    end

    vim.fn.writefile({ tostring(now) }, state_file)

    manage.check({ show = false, clear = false }):wait(function()
      local ok_checker, checker = pcall(require, 'lazy.manage.checker')
      if ok_checker then
        checker.report(true)
      end
    end)
  end,
  desc = '引数なし起動時に1日1回プラグイン更新を確認',
})

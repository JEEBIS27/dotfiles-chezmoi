# Dotfiles

Omarchyを主な対象に、デスクトップ・ターミナル・エディタ・日本語入力を [chezmoi](https://www.chezmoi.io/) で管理する個人用Dotfilesです。

Omarchy shellのカスタムバー、状態に応じて表情が変わるZshプロンプト、Neovim、Yaziを組み合わせています。設定を使いたい方が、自分に必要な部分を選び、変更内容を確認して導入できるようにまとめています。

> **導入前に：** Omarchy本体は別途導入してください。`install.sh` の冒頭で3つの質問に答え、プランを確認してから開始します。選択した設定は既存ファイルをバックアップして適用し、選ばなかった設定は同期しません。

## 目次

- [1. 全体像と対象環境](#overview)
- [2. 導入前に確認すること](#before-install)
- [3. 導入手順](#installation)
- [4. インストールするアプリ・ツール](#packages)
- [5. 同期する設定とファイル構成](#configuration)
- [6. Omarchy・Hyprland・カスタムバー](#desktop)
- [7. Zsh・プロンプト・シェルプラグイン](#shell)
- [8. Neovim・エディタプラグイン](#neovim)
- [9. Yazi・PDF・日本語入力・その他](#applications)
- [キーバインド一覧（Omarchy・端末・Herdr・Neovim・Yazi）](#keybindings)
- [10. 更新・編集・再読み込み](#maintenance)
- [11. トラブルシューティングと復元](#troubleshooting)
- [12. スクリーンショット](#screenshots)
- [13. 参考・謝辞・ライセンス](#references)

<a id="overview"></a>
## 1. 全体像と対象環境

| 分野 | 主な構成 |
| --- | --- |
| デスクトップ | Omarchy / Hyprland（Lua形式の設定）/ Quickshell |
| バー | `jeebis.bar` とワークスペース・アプリ・通知などのカスタムプラグイン |
| ターミナル | WezTerm（標準）。Ghosttyの操作表は旧構成の参考として収録 |
| シェル | Zsh / Sheldon / fzf / zoxide / 独自プロンプト |
| エディタ | Neovim / lazy.nvim / Tree-sitter / Yazi・Oil連携 |
| ファイル・PDF | Yazi / Zathura / eza / bat |
| 日本語入力 | Fcitx5 / Mozkey IBG |
| パッケージ管理 | pacman（Omarchyでは `omarchy pkg`）/ 任意でyay |
| その他 | Git + delta / rclone / LaTeX / VS Code用設定 |

主な利用対象は**Lua形式のHyprland設定とOmarchy shellが動作するOmarchy環境**です。バーとHyprland設定はOmarchy専用です。旧形式の `hyprland.conf` やWaybar向けではありません。

デスクトップ設定を除いたCLI・エディタの導入はArch Linuxでも利用できます。インストーラーはpacmanを前提とし、Ubuntu・Fedora・macOS・WSLへの一括導入は扱いません。

<a id="before-install"></a>
## 2. 導入前に確認すること

- Omarchy（またはデスクトップ設定を使わないArch Linux）、Git、Python 3を用意してください。chezmoiがなければインストーラーがpacmanで導入します。
- システムを通常の手順で更新しておいてください。インストーラーは `pacman -Sy` やOS全体の更新を実行しません。
- 初回は `--dry-run` でプランと設定差分を確認すると、何が変わるか把握できます。
- 既に別のDotfilesをchezmoiで管理している場合は、管理元の統合を先に検討してください。

### 個人情報とマシン固有設定

Gitの名前は既存の `user.name`、なければ現在のログインユーザー名を提案します。メールは既存値または空欄です。作者の名前・メール・平文保存のcredential helperをコピーしません。`--no-personalize` ならGit設定自体を同期しません。Git設定を適用すると既存の `.gitconfig` は置き換わるため、必要な署名・認証・include設定はバックアップから取り込んでください。

`jeebis.*` はプラグインの固定IDであり、ログインユーザー名ではありません。自分のユーザー名への一括置換は行いません。各設定のホーム参照には `$HOME` / `~` / systemdの `%h` を使います。

| 設定 | 注意点 |
| --- | --- |
| Hyprlandのモニター | 現在は倍率 `1.6` / `GDK_SCALE=2`。不要なら `--no-hyprland` で除外し、適用前に `dot_config/hypr/monitors.lua` を確認 |
| WezTermのフォント | 元の `HackGen35 Console NF` を使用。`--fonts` でリポジトリ同梱のTTFとライセンスを同期 |
| Mozkeyの `config1.db` | キー設定・ローマ字変換表などの設定ファイル。`--mozkey` で同期 |
| 既定ブラウザ・メール・PDFなど | `--mime` で元の `mimeapps.list` を同期。Helium・HEY・ChatGPT・Zathura・Yaziの関連付けが入る |
| VS Code・WezTerm | `--vscode` / `--wezterm` で同期。WezTermは本体も導入し、LinuxではWSLドメインを指定しない |
| rclone | `--rclone` は本体とサービス定義の導入。認証済みremoteが必要なのは `--cloud-mounts` による起動時のみ |

`private_` はchezmoiによるアクセス権限の指定で、暗号化やGitからの除外ではありません。自分のforkに認証情報などを追加しないでください。

### バックアップの範囲

インストーラーは、選択した適用対象の既存ファイルと元の選択プロフィールを、`~/.local/state/dotfiles/backups/日時.ランダム文字列/` に保存します（`XDG_STATE_HOME` に対応）。`manifest.json` には各ファイルが元から存在したかも記録します。

システム全体のスナップショットではありません。パッケージ、日本語ロケール、ログインシェル、サービス有効化は別途戻す必要があります。重要な既存環境は、通常のバックアップも用意してください。

<a id="installation"></a>
## 3. 導入手順

### 3.1 取得する

新しいOmarchy / Arch環境では、まずリポジトリを取得します。

```bash
sudo pacman -S --needed git python
git clone https://github.com/JEEBIS27/dotfiles.git ~/.local/share/chezmoi
bash ~/.local/share/chezmoi/install.sh
```

chezmoiが未導入なら、インストーラーがパッケージ導入段階で用意します。既に取得済みの場合はcloneを繰り返さず、`bash "$(chezmoi source-path)/install.sh"` を実行します。自分のforkを使う場合はURLを置き換えてください。

chezmoiを先に用意する場合は [公式ガイド](https://www.chezmoi.io/install/) または `sudo pacman -S --needed chezmoi` を利用し、`chezmoi init https://github.com/JEEBIS27/dotfiles.git` で取得しても構いません。プロフィール未作成でも、個人設定一式を既定の同期対象にします。インストーラーでは各項目を既定で有効にし、不要なものを `--no-項目名` または質問へのNoで除外します。通常の `chezmoi apply` はファイルの同期だけなので、パッケージ導入を伴う初回構築には `install.sh` を使ってください。

### 3.2 3つの質問に答える

設定をアプリごとに確認せず、「このDotfilesで既存設定を上書きするか」を一度だけ確認します。通常の質問は次の3つです。

| 質問 | 既定値 | まとめて扱う内容 |
| --- | --- | --- |
| このDotfilesで既存設定を上書きしますか？ | Yes | バー・Hyprland・Zsh・Neovim・WezTerm・Yazi・VS Code・既定アプリなど。上書き前にバックアップ |
| アプリ・CLI・フォントをまとめて導入しますか？ | Yes | 不足している本体・CLI・curl/wget・HackGen・Rustup・LaTeX・rcloneなど |
| 日本語入力・日本語ロケールも設定しますか？ | Yes | Fcitx5・Mozkey・日本語ロケール |

その後、導入プランをまとめて表示し、最後に開始を一度だけ確認します。明示したオプションの項目は質問を省き、`--non-interactive` なら質問も開始確認も省きます。

Omarchyは自動判定します。Gitの名前は既存設定、なければログインユーザー名を使い、メールは既存値または空欄を使います。名前・メールを変える場合は `--git-name` / `--git-email` で指定できます。

設定の質問にNoと答えると、このDotfilesによる設定同期・ロケール変更・ログインシェル変更・サービス起動を行いません。ツールの導入は別の質問で選べます。ツールにNoと答えても、既にあるアプリ向けの設定を同期できます。日本語にNoなら、明示的に `--mozkey` を指定した場合を除き、日本語入力の導入・同期も省きます。

標準ターミナルはWezTermです。Ghostty設定は常に同期対象外とし、本体の導入だけが必要な場合は `--ghostty` を指定できます。以前のプロフィールにGhosttyが有効と記録されていても、自動で再導入しません。

AUR・Neovim最新版・クラウドマウント・lingerなどの詳細は質問を増やさず、保存済み選択または個別オプションで指定します。各アプリ・設定も `--no-hyprland` / `--no-neovim` などで除外でき、既存の除外は維持します。

### 3.3 コマンドラインで指定する

`--no-settings` は設定の上書き・同期をまとめて省き、`--no-packages` はツールの導入を省きます。細かく除外したい場合は各機能の `--no-機能名` を使えます。

```bash
# 通常の対話形式
bash "$(chezmoi source-path)/install.sh"

# 質問なしでプラン・差分だけ確認（設定やパッケージは変更しない）
bash "$(chezmoi source-path)/install.sh" --non-interactive --omarchy --dry-run

# 既存の設定を保ち、ツールだけ導入する
bash "$(chezmoi source-path)/install.sh" --no-settings

# 導入済みツールに対して設定だけ同期する
bash "$(chezmoi source-path)/install.sh" --no-packages

# 標準のWezTerm構成で、不要な部分だけ除外する
bash "$(chezmoi source-path)/install.sh" \
  --non-interactive --no-hyprland --no-latex

# 作者の環境を再構築するための選択で、変更内容だけ確認
bash "$(chezmoi source-path)/install.sh" --preset owner --non-interactive --dry-run

# 作者向けの選択で導入。必要なら --no-latex などを追加
bash "$(chezmoi source-path)/install.sh" --preset owner --non-interactive

# 選択だけ保存。導入・設定適用は後で行う
bash "$(chezmoi source-path)/install.sh" --configure-only

# 全オプションを確認
bash "$(chezmoi source-path)/install.sh" --help
```

`--non-interactive` は未指定項目に保存済みの回答、なければ上表の既定値を使います。`--preset owner` は未指定項目に作者環境向けの既定値を使い、過去の選択よりプリセットを優先します。明示した有効／無効オプションは常に優先します。通常は不要な項目だけを指定できます。固定した構築条件が必要な場合は、各オプションを明示してください。`owner` はCLI・curl/wget・HackGen・Mozkey・Rustup・VS Code・WezTerm・MIME・バー・Hyprland・LaTeX・rclone定義・Zshへの変更を有効にします。既存Neovimを使い、クラウドのマウントとlingerは自動有効化しません。sudoの認証は別途必要です。設定の上書き確認も省略し、バックアップ後に**選択した設定だけ**を適用します。

`--configure-only` はプロフィールの保存だけを行い、パッケージ導入・ロケール変更・設定適用を実行しません。後で `chezmoi apply` した場合も、パッケージは導入されません。システム側のセットアップまで進める場合は `install.sh` を再実行してください。

### 3.4 選択の保存と実行順

選択内容は `~/.config/chezmoi/dotfiles.json` に保存します（`XDG_CONFIG_HOME` に対応）。このファイルはリポジトリへ追加しません。

1. オプション解析・質問・導入プラン確認。
2. 前提条件の検査（Omarchy、yay、必要ならrcloneのremoteなど）。
3. 不足している公式パッケージを導入し、必要な場合にAUR・専用導入処理を実行。
4. 適用対象のバックアップとプロフィールの保存。
5. 選択した設定ファイルをchezmoiで適用。
6. 選択した場合のみ日本語ロケール・ログインシェル・rcloneサービス・lingerを設定。

対話・選択・適用の入口は [`install.sh`](install.sh) に集約しています。pacmanにないものの個別処理は [`scripts/install-extras.py`](scripts/install-extras.py)、Mozkeyのパッケージ定義は [`scripts/mozkey.PKGBUILD`](scripts/mozkey.PKGBUILD) に置いています。旧 `.chezmoiscripts/run_once_*.sh` は廃止しました。通常の `chezmoi apply` / `update` は保存した選択に沿ってファイルを同期するだけで、導入処理は再実行しません。

機能を無効にした場合、今後の同期から外れます。既に配置したファイルの削除、アプリのアンインストール、以前変更したロケール・シェル・サービスの巻き戻しは行いません。

### 3.5 適用後の確認

```bash
chezmoi status
command -v zsh nvim wezterm yazi
```

新しいターミナルを開き、Neovimでは初回のプラグイン取得を待ちます。日本語・ログインシェルを変更した場合は再ログインしてください。バーやHyprlandの再読み込みは[更新・編集](#maintenance)を参照してください。

<a id="packages"></a>
## 4. インストールするアプリ・ツール

**公式パッケージを優先し、元の導入対象を維持**しています。Omarchyでは `omarchy pkg add`、通常のArchでは `sudo pacman -S --needed` を使います。導入済みのものを先に除外し、パッケージマネージャー側でも `--needed` を使います。

| 選択 | 導入するもの |
| --- | --- |
| 初期準備 | 未導入なら `chezmoi` / `git` |
| 利用者設定 | `git` / `git-delta` |
| CLI | `git` / `zsh` / `sheldon` / `eza` / `bat` / `git-delta` / `dust` / `fzf` / `zoxide` / `ripgrep` / `fd` / `unzip` / **`stow`** |
| ダウンロードツール | **`curl` / `wget`** |
| Neovim | 既存本体を利用、なければ `neovim`。`base-devel`、Rustupを選ばずCargoもない場合は `rust` |
| Neovim最新版 | `--neovim-latest` でGitHubの最新Linux tarballを `~/.local` に導入。x86_64 / aarch64対応 |
| Ghostty（任意） | `--ghostty` を明示した場合のみ本体を導入。設定は同期しない |
| HackGen | 現環境から取り込んだNerd Fonts版TTF 4ファイルとライセンスを `~/.local/share/fonts/HackGen` に同期。`fontconfig` を導入 |
| Rustup | 既存のRustup、公式 `rustup`、または公式インストーラーを使い、stable toolchainを用意 |
| ファイル管理 | `yazi` / `zathura` / `zathura-pdf-mupdf` / `ffmpeg` / `7zip` / `jq` / `poppler` / `imagemagick` |
| 日本語 | `fcitx5` / `fcitx5-gtk` / `fcitx5-qt` / `fcitx5-configtool`。Mozkeyを選ばない場合は `fcitx5-mozc` |
| Mozkey | 公式リポジトリにあればそのパッケージ。なければAURまたは同梱PKGBUILDから `mozkey-ibg-bin` を導入 |
| WezTerm | `wezterm` と元の設定 |
| LaTeX | `texlive-bin` / `texlive-basic` / `texlive-latex` / `texlive-latexrecommended` / `texlive-binextra` / `texlive-langjapanese` / `texlive-mathscience` |
| rclone | `rclone` / `fuse3` とサービス定義。認証・起動とは独立 |

### pacmanにないものの導入経路

- **HackGen**：`dot_local/share/fonts/HackGen/` に同梱した `HackGen35 Console NF` と `HackGen Console NF`（各Regular・Bold）のTTF・配布ライセンスを、`~/.local/share/fonts/HackGen/` へ同期します。外部ダウンロードやAURは不要です。導入後に `fc-cache` を更新します。`--no-fonts` で同期対象から外せます。設定上書きにNoと答えた場合もフォントは同期しません。通常の `chezmoi apply` ではTTFの変更時にキャッシュを更新します。フォント更新時は管理元のTTFとライセンスを手動で更新してください。
- **Mozkey**：`v0.10.4` のArch向け配布物を使う同梱PKGBUILDをmakepkgでビルド・導入します。配布物のSHA-256と依存関係を定義し、pacman管理のパッケージとして登録します。現在の検証済みArch配布物はx86_64用です。
- **Rustup**：システムの `rust` と競合する場合は、公式インストーラーでユーザー領域へ導入します。既にあるtoolchain・既定値を保ち、stableがなければ追加します。初回で既定値がなければstableを選びます。
- **Neovim最新版**：GitHubが公開するSHA-256 digestを確認して展開します。通常は既存本体を使い、この経路は明示的に選んだ場合のみ実行します。
- **AUR**：`--aur` はMozkeyの取得でAURを優先する選択です。yayがなければ `yay-bin` のPKGBUILDから用意します。選ばなくても専用経路で導入できます。

curl/wgetはツールの一括導入に含みます。`--no-downloads` で外しても、Mozkey・Rustupなどが必要とする場合は依存としてcurlを導入します。

別途必要なもの：ChatGPT / Codex / Copilot CLI / Aether、Node.js / NVM、各言語のLSP・フォーマッター、クラウド認証など。Aether起動には `~/.local/bin/aether` と `webkit2gtk-4.1` が必要です。これらは旧構成でも一括導入の対象ではありません。

<a id="configuration"></a>
## 5. 同期する設定とファイル構成

chezmoiの管理元名では `dot_` が `.`、`executable_` が実行可能ファイル、`private_` がアクセス権限の制限、`.tmpl` がテンプレートを表します。

| 管理元 | 用途・同期条件 |
| --- | --- |
| `install.sh` | 対話・オプション解析・パッケージ・バックアップ・適用。ホームにはコピーしない |
| `.chezmoiignore` | 保存した選択に従って同期対象を絞る |
| `dot_local/share/fonts/HackGen/` | `--fonts` でTTF 4ファイルと配布ライセンスを同期 |
| `.chezmoiscripts/run_onchange_after_font-cache.sh.tmpl` | 通常のapplyでフォント変更後にキャッシュを更新 |
| `.chezmoitemplates/profile` | 端末ごとのプロフィールを読み込む共通テンプレート |
| `dot_gitconfig.tmpl` / `dot_config/delta/` | 利用者設定を選択した場合のGit・delta |
| `dot_zshrc` / `dot_config/zsh/` / `dot_config/sheldon/` / `dot_config/bat/` | CLIを選択した場合 |
| `dot_config/hypr/` | Hyprlandを選択した場合 |
| `dot_config/omarchy/` / `dot_local/bin/executable_jeebis-bar-action` | バーを選択した場合 |
| `dot_config/ghostty/config.tmpl` | 旧構成の参考。設定の自動同期は行わない |
| `dot_config/nvim/` | Neovimを選択した場合 |
| `dot_config/herdr/config.toml` / `dot_config/tmux/tmux.conf` | CLIを選択した場合のマルチプレクサ設定。本体はOmarchyなどで別途用意 |
| `dot_config/yazi/` / Yaziのdesktopファイル | ファイル管理を選択した場合 |
| `dot_config/fcitx5/` / `dot_config/private_mozkey-ibg/config1.db` | 日本語・Mozkeyの選択に従って同期。キー設定も含む |
| `dot_config/tex/` | LaTeXを選択した場合 |
| `dot_config/systemd/user/rclone-*.service` | rcloneを選択した場合 |
| `dot_config/mimeapps.list` | `--mime` で元の関連付けを同期 |
| `dot_config/wezterm/` / `dot_config/vscode/` | `--wezterm` / `--vscode` で同期 |
| `scripts/` | 専用インストーラー・Mozkeyパッケージ定義。ホームへはコピーしない |
| `tests/test_install.py` | 隔離環境とモックによるインストーラー検証 |

正確な同期対象は `chezmoi managed`、除外対象は `chezmoi ignored` で確認できます。README・テスト・インストーラー・同梱テーマ内のGit管理情報もホームへコピーしません。

<a id="desktop"></a>
## 6. Omarchy・Hyprland・カスタムバー

### Hyprland

[`dot_config/hypr/hyprland.lua`](dot_config/hypr/hyprland.lua) からOmarchyのbootstrap・既定設定を読み、その後にユーザー設定を読み込みます。`/usr/share/omarchy` または `OMARCHY_PATH` のOmarchy本体が必要です。

| ファイル | 変更する内容 |
| --- | --- |
| `monitors.lua` | 解像度・配置・拡大率 |
| `input.lua` | キーボード・マウス・タッチパッド |
| `bindings.lua` | キー割り当てとウィンドウ操作 |
| `looknfeel.lua` | 余白・装飾・アニメーション |
| `autostart.lua` | 追加の自動起動（現在はコメントのみ） |
| `hyprsunset.conf` / `xdph.conf` | 夜間表示・ポータル関連 |

ウィンドウ操作と起動キーは[Hyprlandのキー一覧](#keys-hyprland)、メニューやコピー操作は[Omarchyのキー一覧](#keys-omarchy)にまとめています。Superは通常Windowsキーに相当します。

Yaziは登録済みの`yazi.desktop`を`gtk-launch yazi`で起動します。desktopファイル名の大文字小文字は区別されます。

### バーとウィジェット

レイアウトは [`dot_config/omarchy/private_shell.json`](dot_config/omarchy/private_shell.json)、大きさは `private_shell.toml` で管理します。現在は画面上部、ワークスペースを中央基準に配置しています。

| プラグイン | 役割・操作 |
| --- | --- |
| `jeebis.bar` | カスタムバー本体。各「島」の配置・表示・アニメーションを制御 |
| `jeebis.theme` | クリックでテーマ選択、ダブルクリックでAether |
| `jeebis.power` | バッテリー・電源プロファイル・システム情報 |
| `jeebis.load` | CPU・メモリ・ロードアベレージの表示 |
| `jeebis.agent-launchers` | ChatGPT / Codexの起動・フォーカス、稼働状態の表示 |
| `jeebis.workspaces` | 実在するワークスペースのドットと負荷・起動時のスピナー |
| `jeebis.apps` | 現在のワークスペースのアプリ一覧。クリックでウィンドウをフォーカス |
| `jeebis.notifications` | 未読通知・履歴・既読操作 |
| `jeebis.clock` | 日時とカレンダーパネル |
| `jeebis.overview` | ワークスペース・ウィンドウの一覧。現在はgrid、検索無効 |
| `jeebis.islands` | 別の3島型バーも収録。現在選択中のバーは `jeebis.bar` |

モニター・ネットワーク・Bluetooth・音声・Agent情報にはOmarchy標準プラグインも使います。カスタムプラグインだけを他のQuickshell環境へコピーしても動作する構成ではありません。

アプリ島は必要なタイミングやホバーで表示され、アプリの起動・終了時に合流・分離の動きをします。ワークスペース島は通常2つ以上のワークスペースで表示され、1つだけなら隠れます（高負荷時の表示は例外）。ChatGPT / CodexはAgent側に分けて表示します。

### アニメーションとテーマ

時間調整は `~/.config/omarchy/plugins/jeebis.bar/AnimationTiming.js` に集約しています。単位はミリ秒です。

| グループ | 調整対象 |
| --- | --- |
| `appIsland` / `appArrival` / `appDeparture` | アプリ島の表示・起動時の合流・終了時の分離 |
| `agentIsland` / `agentActivity` | Agent島・ボタン・稼働状態の変化 |
| `workspaceIsland` / `workspaceActivity` | ワークスペース島・スピナー |
| `notificationIsland` / `notificationClear` / `notificationHistory` | 通知島・既読・履歴 |
| `loadIsland` | 負荷表示 |
| `powerMessage` / `powerStatus` / `powerGauge` | 電源パネル |
| `calendarProgress` | カレンダーの進捗表示 |

`preparingMs` / `enteringMs` / `presentMs` / `leavingMs` などのフェーズを調整します。合計時間から後続の開始を計算する箇所もあるため、まず定数直前のコメントを確認してください。変更後は `omarchy restart shell` で全体を読み直します。

Omarchyのテーマには `aether` / `black-and-white` / `luckystar-otaku` / `microsoft-surface-black` の色・アイコン設定を収録しています。壁紙や外部アプリも含めた一式が揃うことは保証していません。Neovim・Yazi・WezTermの配色はOmarchyの共通パレットから生成します。

テーマ変更はバーのテーマ選択、`omarchy theme set <名前>`、または **Super+Alt+T** で行います。Super+Alt+Tは **Tokyonight → Kanagawa → Catppuccin → Tokyonight** の順で切り替え、完了後にテーマ名をOmarchy標準の操作確認ポップアップで通知します（通知抑制中も表示）。CatppuccinはOmarchy標準テーマを使用します。個人用 `tokyonight` がない端末では標準の `tokyo-night` を使います。3テーマ以外からはTokyonightへ、`kanagawa-wave` からはCatppuccinへ進みます。

| ツール | 連携方法・反映タイミング |
| --- | --- |
| Neovim | `themed/palette.lua.tpl` から生成した色を読み込み、起動中も約1秒で反映。透明背景を維持 |
| WezTerm | `themed/wezterm.toml.tpl` を読み込み、テーマディレクトリの置換を監視して自動再読込。タブ色も連携 |
| Yazi | `theme.toml` は生成した `yazi.toml` へのリンク。コードプレビューも共通パレット。変更後はYaziを開き直す |
| bat / fzf | batはOmarchy生成の `preview.tmTheme` をYaziと共有し、テーマ変更時にキャッシュを再生成。fzfは端末のANSI色に追従。Zshの `BAT_THEME` 変更は新しいシェルから有効 |
| Ghostty / btop | 既存のOmarchy連携を使用 |
| Herdr / tmux | 既存の端末色・ANSI色の設定を使用 |

`~/.config/omarchy/themed/` はchezmoiに同期します（プロフィールの `omarchy` が必要。バー同期の有効・無効とは独立）。apply後の `run_onchange_after_omarchy-theme.sh` が現在のテーマを再生成します。生成先の `~/.local/state/omarchy/current/theme/` は実行時データなので同期しません。OmarchyがないホストではNvimは既定色、WezTermは同梱の `omarchy.toml` の保存配色を使います。Yaziのリンクを使うにはOmarchyとテーマ生成が必要です。`apply_setting.sh` でWindowsへコピーするときは、その時点のOmarchy配色もコピーします。Windows側へのリアルタイム連携は行いません。

テーマ自体も `~/.config/omarchy/themes/<名前>/` の `colors.toml`・`icons.theme`・壁紙・プレビューを `chezmoi add` すれば同期できます。標準テーマはOmarchyが提供し、変更分は同名のユーザーディレクトリに置きます。今回、生成済みデータしか残っていなかった現在の `kanagawa-wave` は `colors.toml` と `icons.theme` をユーザーテーマとして復元して同期しました。他の追加・変更されたテーマ本体の一括取り込みは行っていません。Kanagawa・Tokyonight・Catppuccin の指定壁紙は `~/.config/omarchy/backgrounds/<テーマ名>/` に保存し、chezmoi に同期します。元画像は `~/Wallpapers/kanagawa-cup.jpg`・`tokyonight.jpg`・`catppuccin.png` です。標準テーマのファイルは編集せず、壁紙の追加分として管理します。別端末では `omarchy theme set <名前>` で選択してください。選択中のテーマ名や実行時データは同期対象にしません。

現在のidle設定はスクリーンセーバー150秒、ロック300秒です。`hooks/` の `.sample` はサンプルで、`post-update.d` の実行可能フックは指紋認証・既定Agent・Voxtypeの設定を通知で案内します。

<a id="shell"></a>
## 7. Zsh・プロンプト・シェルプラグイン

### プロンプトと設定場所

Starshipではなく `.zshrc` 内の独自プロンプトです。時刻、カレントディレクトリ、Gitブランチ・変更の有無を表示し、コマンド失敗・3秒以上の処理・sudo・移動などで顔と入力色が変わります。設定値は `~/.config/zsh/config.sh` にあります。

```zsh
prompt-face-toggle  # 顔表示の切り替え（on / offも用意）
prompt-bg-toggle    # 背景装飾の切り替え（on / offも用意）
```

### Sheldonで読み込むもの

定義元は [`dot_config/sheldon/plugins.toml`](dot_config/sheldon/plugins.toml) です。Oh My Zsh全体を導入する構成ではありません。

| プラグイン | 用途 |
| --- | --- |
| Oh My Zsh `extract` | アーカイブ形式を判定して展開する関数 |
| `zsh-autosuggestions` | 入力候補の提示 |
| `zsh-completions` | 補完定義 |
| `zsh-syntax-highlighting` | コマンド入力の色分け |
| `you-should-use` | 利用できるエイリアスの案内 |
| `fzf` / `fzf-tab` | 履歴・ファイル検索とTab補完 |
| `zoxide` | 移動履歴を使った `cd` |
| `zsh-history-substring-search` | 入力文字列を使った履歴検索 |

初回の読み込みには取得元へのネットワーク接続が必要です。fzfは公式パッケージを使います。Sheldonはインストール済みfzfのシェル連携だけを読み込みます。

`Ctrl+R` でfzfの履歴検索を開き、`Esc` で閉じられます。

### よく使うコマンド

`f/g/d/y`はコマンドとして残し、[Zshの直接キー](#keys-zsh)からも呼び出します。

| コマンド | 動作 |
| --- | --- |
| `d [文字列]` | zoxide履歴をfzfで選んで移動 |
| `f [文字列]` | ファイルを検索・batでプレビューし、エディタで開く |
| `g [文字列]` | ripgrep検索結果から選び、Neovimで該当行を開く |
| `y` | Yaziを起動し、終了時に選んだディレクトリへ移動 |
| `ls` / `ll` / `la` / `lt` | ezaで一覧・詳細・隠しファイル・2階層ツリー |
| `md path` | ディレクトリを作成して移動 |
| `cat` / `nv` / `_` | bat / Neovim / sudo |
| `gs` / `gd` / `ga` / `gc` / `gp` | Gitのstatus / diff / add / commit / push |
| `google 検索語` | ブラウザでGoogle検索 |
| 行頭の `|` | コマンドの標準出力を表示しながらクリップボードへコピー |

コピー・移動・削除に確認付き実行と移動・一覧を組み合わせる関数群もあります（`pc` / `mc` / `rc`、`pcls` / `mcls` / `rcls` など）。詳細は `my_alias.zsh` を確認してください。`rm` 系はゴミ箱への移動ではありません。

### アーカイブ展開

```zsh
extract archive.tar.gz
extract -t ~/tmp package.zip
extract first.zip second.7z
extract -r old-backup.tar.xz
```

`-t` は展開先、`-r` は成功後の元アーカイブ削除です。形式に応じて `tar` / `unzip` / `7z` などの実行コマンドが必要です。

`extract` プラグインの `x` エイリアスでアーカイブを展開します。`clear && ls` はZLEの `Ctrl+L` に割り当てており、画面を消去して現在のディレクトリ一覧を表示します。

プラグイン追加・更新用に `zsh-plugin-add owner/repo`、`zsh-plugin-remove 名前`、`zsh-plugin-list`、`zsh-plugin-update`、`zsh-plugin-reload` を用意しています。

<a id="neovim"></a>
## 8. Neovim・エディタプラグイン

`init.lua` から基本設定、lazy.nvim、キー割り当てを読み込みます。lazy.nvim本体は初回起動時にGitHubから取得します。プラグインのリビジョンは `lazy-lock.json` で管理します。

| 分野 | 主なプラグイン |
| --- | --- |
| 管理・案内 | `lazy.nvim` / `which-key.nvim` / `mason.nvim` |
| 検索・ダッシュボード | `snacks.nvim` |
| ファイル操作 | `oil.nvim` / `yazi.nvim` |
| 構文・構造 | `nvim-treesitter` / context / textobjects / `vim-matchup` / `nvim-ts-autotag` |
| 編集 | `flash.nvim` / `mini.ai` / `Comment.nvim` / `vim-sandwich` / `vim-exchange` / `dial.nvim` |
| コード・ターミナル | `treesj` / `toggleterm.nvim` |
| 表示 | `statuscol.nvim` / `incline.nvim` / `gitsigns.nvim` / `noice.nvim` / `nvim-notify` / `hlchunk.nvim` / `vimade` |
| 配色 | Omarchyの共通パレット（Kanagawaはハイライト定義のエンジンとして使用） |

LSP・補完用には `nvim-lspconfig` / `blink.cmp` / `copilot.lua` / `conform.nvim` / `lspsaga.nvim` / `overlook.nvim` の定義もあります。**現在の `config/lazy.lua` は `plugins.lsp` と `plugins.lang` を明示的にimportしていません。** ファイルがあるだけで全機能が有効になるとは限らないため、利用する場合はimportと `:Lazy` の一覧を確認してください。

LSP設定にはGo、TypeScript / Vue、JSON / YAML、Lua、Python、Bash、Nixなどの定義がありますが、サーバー本体の一括自動導入はありません。Masonの導入と、各ツールのインストールは別です。補完のビルドにはCargo、CopilotにはNode.jsと利用認証が必要です。

### 基本操作

直接キーとSpaceから始まる補助操作は[Neovimのキー一覧](#keys-neovim)にまとめています。ディレクトリを開く既定の処理とExplorerの入口にはYaziを使い、Oilは`:Oil`で別途開けます。

| コマンド | 用途 |
| --- | --- |
| `:Yazi` / `:Oil` | ファイル操作 |
| `:Lazy` / `:Mason` / `:checkhealth` | プラグイン / 外部ツール / 診断 |

statuscolではダッシュボード・特殊バッファを通常の行番号装飾から除外しています。

<a id="applications"></a>
## 9. Yazi・PDF・日本語入力・その他

### YaziとPDF

Yaziは隠しファイル表示、3ペイン比率 `1:4:3`、画像・動画・PDFなどのプレビューを設定しています。配色とコードプレビューはOmarchyに連携します。旧Kanagawa・Tokyo Night Nightのflavorは参照用に残しています。`package.toml` の追加プラグイン依存は空です。

`h/j/k/l` で移動、`Enter` で開く、`.` で隠しファイルの表示切り替え、`s` / `S` でファイル名・内容検索ができます。シェルの`y`は終了時のディレクトリへ移動し、デスクトップ起動では終了後にその場所のシェルを開きます。詳細は[Yaziのキー一覧](#keys-yazi)を参照してください。

Yaziエントリーは `xdg-terminal-exec` を使うため、そのコマンドも必要です。`--mime` を選べば収録した既定アプリ設定も同期します。選ばず、PDFとフォルダだけを変更したい場合は次を実行します。

```bash
xdg-mime default yazi.desktop inode/directory
xdg-mime default org.pwmt.zathura.desktop application/pdf
```

### 日本語入力

`--japanese` はFcitx5の導入と `ja_JP.UTF-8` のシステムロケールを設定します。`--mozkey` はMozkey本体とキー設定の導入を選びます。初回の既定値は日本語設定への回答に追従し、AURを使わない場合もMozkeyを導入できます。明示的に `--no-mozkey` を選んだ日本語環境ではMozcを使います。

**`config1.db` は履歴DBではなく、Protocol Buffers形式の設定ファイルです。** 実ファイルを[上流のConfig定義](https://github.com/kazormia296/mozkey-ibg/blob/main/src/protocol/config.proto)と照合し、160行のカスタムキーマップ（フィールド42）、334行のローマ字変換表（フィールド43）、変換・表示・学習の有効／無効などの設定を確認しました。学習の有効／無効は履歴内容そのものではありません。現在のファイルに入力履歴や認証情報は確認されず、`--mozkey` の同期対象に戻しています。ファイル名とシリアライズ方式は[ConfigHandler](https://github.com/kazormia296/mozkey-ibg/blob/main/src/config/config_handler.cc)でも確認できます。

再ログイン後にFcitx5の設定画面でMozkeyを選んでください。`--mozkey --no-japanese` なら、システムロケールを変更せずに入力環境と設定を導入できます。

### rclone

`--rclone` は `/usr/bin/rclone`・FUSE3・ユーザーサービス定義を用意します。未認証でも導入できます。

```bash
# まず本体と定義を用意
bash "$(chezmoi source-path)/install.sh" --rclone
# 自分のアカウントで gdrive: と onedrive: を作成
rclone config
# 必要なら次回の実行でマウントも有効化
bash "$(chezmoi source-path)/install.sh" --rclone --cloud-mounts
```

`--cloud-mounts` を選ぶと、認証済みremote名と空のマウント先を確認してから、`~/GoogleDrive` / `~/OneDrive` のマウントサービスを有効化・起動します。`--linger` を併用すればログアウト後のユーザーサービス常駐も設定できます。認証情報は配布しません。

### LaTeX・VS Code・WezTerm

- **LaTeX**：シェルの `latexmk` エイリアスが `~/.config/tex/.latexmkrc` と `-pvc` を指定します。クラスに応じたLuaLaTeX / pLaTeX切り替え、`.build` への生成物整理、Zathuraプレビューを設定しています。成功後の処理では同じベース名のファイルを移動するため、初回は文書のコピーで動作を確認してください。
- **VS Code**：`--vscode` で元の `~/.config/vscode/setting.json` と `keybindings.json` を同期します。このパス・`setting.json` という名前は通常のLinux版Codeの `~/.config/Code/User/settings.json` と異なるため、利用先に合わせた手動配置・調整が必要です。拡張機能の自動導入はありません。
- **WezTerm**：フォント・配色・タブ・ペイン操作を収録し、日常操作は `Ctrl+Alt` の直接ショートカットに統一し、Leaderは使いません。`--wezterm` で本体と設定を導入します。WindowsのときだけWSLドメインを使います。タブは場所のNerd Fontアイコンを表示し、アプリ実行中はアプリ名も表示します。LinuxのWayland環境では `window_decorations = "NONE"` とし、灰色のタイトルバー・最大化ボタンが出る問題を回避します。枠・移動・リサイズはHyprlandに任せ、Windows等では `RESIZE` を維持します。Windows転送用スクリプトはWSLでWindowsユーザーを自動検出し、引数でコピー先も指定できます。

<a id="keybindings"></a>
## キーバインド一覧

2026-10-18更新。この章をキー割り当ての参照元とし、設定変更時には対応する表も更新します。

- [修飾キーの役割と共通ルール](#keys-model)
- [Omarchy](#keys-omarchy) / [Hyprland](#keys-hyprland)
- [WezTerm](#keys-wezterm) / [Herdr](#keys-herdr) / [tmux](#keys-tmux)
- [Neovim](#keys-neovim) / [Yazi](#keys-yazi) / [Zsh・fzf](#keys-zsh)
- [競合・入力転送・確認方法](#keys-validation)

<a id="keys-model"></a>
### 修飾キーの役割と共通ルール

Modは以下の層ごとの修飾キーです。同じ文字キーで、その層にある対象へ同じ種類の操作を行います。

| 層 | Mod | 担当 |
| --- | --- | --- |
| Hyprland / Omarchy | Super | デスクトップのウィンドウ・ワークスペース |
| WezTerm | Ctrl+Alt | 通常の端末ペイン・タブ・ワークスペース |
| Herdr / tmux | Alt | 継続作業のペイン・タブ・ワークスペース |
| Neovim / Yazi / Zsh | Ctrl | アプリの領域・検索・ファイル操作 |

Shiftはリサイズ、派生操作、モード変更、大きな単位を表します。機能のない層は未割当です。通常操作は直接キーで、交換だけはMod+Eの後に方向を選びます。Eの後はModを離して構いません。Escで取り消します。

| 基本キー | 意味 | Shift追加 |
| --- | --- | --- |
| H/J/K/L・矢印 | 左/下/上/右へ移動 | リサイズ |
| Enter | 右へ分割 | 下へ分割 |
| W | 現在の対象を閉じる・中断 | 大きな単位を閉じる |
| F | 検索 | 最大化・復元 |
| T | フロート・補助ターミナル | レイアウト等のモード変更 |
| N | 新規作成 | 大きな単位などの関連する作成 |
| Y | Yazi | コピーモード |
| E → HJKL・矢印 | 方向を指定して交換 | — |
| Tab | タブ等の大きな単位を次へ | 同じ単位を前へ |
| PageUp / PageDown | 通常単位の前 / 次 | 大きな単位の前 / 次 |

| 対象 | 通常の移動単位 | Shift追加の移動単位 |
| --- | --- | --- |
| Hyprland | ウィンドウ | ワークスペース |
| WezTerm / Herdr | タブ | ワークスペース |
| tmux | window | session |
| Neovim | バッファ | タブページ |
| Yazi | タブ | — |

Mod+Tab / Mod+Shift+Tabは同じ単位の次 / 前です。Hyprlandではワークスペース、WezTerm・Herdr・Yaziではタブ、tmuxではwindow、Neovimではタブページを移動します。ペイン・ウィンドウ内の方向移動はMod+HJKLです。Zshには独立したタブがないため追加しません。PageUp/Down系のShiftは従来どおり移動単位を大きくします。

コピー・貼り付けは対象に合う操作を維持します。OmarchyはSuper+C/V/X、Neovim/YaziはVimのy/d/p等です。通常はWezTerm直下にZshやNeovimを置き、永続化が必要な作業をHerdrまたはtmuxで開きます。

<a id="keys-omarchy"></a>
### Omarchy：起動・メニュー・共通クリップボード

| キー | 操作 |
| --- | --- |
| Super+Space | Omarchyメニュー |
| Super+F | アプリ検索 |
| Super+Y | Yaziファイルマネージャー |
| Super+N / Super+Shift+N | 新規ターミナル / エディター |
| Super+C / V / X | ユニバーサルコピー / 貼り付け / 切り取り |
| Super+Ctrl+V | クリップボード履歴 |
| Super+Shift+S | スクリーンショット |
| Super+Alt+D / Super+Alt+Shift+D | 最大幅で開くHerdr経由のCodex TUI / 現在のワークスペースにChatGPTの新規ウィンドウ |
| Super+Alt+Enter / Super+Alt+Shift+Enter | ターミナル / ブラウザの補助入口 |
| Super+Alt+Shift+F | GUIファイルマネージャー |
| Super+Alt+Shift+K | 全体キーバインド一覧 |
| Super+Alt+T | Tokyonight → Kanagawa → Catppuccinを順に切り替え、テーマ名を通知 |

Super+Alt+DはHyprlandが処理し、`~/.local/bin/jeebis-codex-herdr`からCodex専用のHerdrセッション`codex`を開きます。起動したCodexウィンドウは幅最大化します。Super+Shift+Fは最大幅との切り替えで、最大幅から戻すときは元の幅ではなく約50%幅になります。初回はCodex CLIを起動し、再度開くと同じセッションへ接続します。Codex終了後や追加ペインでは通常のZshを使います。Superキーはデスクトップ層、Ctrl+Altは外側のWezTerm、AltはHerdr、Ctrlは内側のアプリが担当します。HerdrのAlt+Dはデタッチで、Super+Alt+Dとは衝突しません。

ChatGPTの起動キーはHyprlandが処理し、`~/.local/bin/jeebis-chatgpt-new-window`がアプリ内の「新しいウィンドウ」を呼び出します。`~/.codex/keybindings.json`の`newWindow`にCtrl+Alt+Shift+Nを割り当てています。このキーはChatGPT内でのみ処理し、WezTerm・Herdr・Neovim・Yaziのキー配置は変更しません。別ワークスペースの既存ウィンドウは残ります。Heliumは`~/.config/helium-browser-flags.conf`の`--new-window`で外部リンクを現在のワークスペースの新規ウィンドウに開きます。`~/.local/share/applications/helium.desktop`はユーザー側の`~/.local/bin/omarchy-launch-browser`を使います。この入口は、URLを開いた後に別ワークスペースの既存ブラウザへフォーカスを移しません。Omarchy標準の起動処理から呼ばれた場合も、既存ブラウザをフォーカスする対象にはなりません。

Super+Alt+TはHyprlandが処理するデスクトップ共通キーです。未割当のキーを使用し、WezTerm・Herdr・Neovim・Yazi内からも同じ操作になります。WezTermのCtrl+Alt系、HerdrのAlt+T、NeovimのCtrl+Tとは衝突しません。

<a id="keys-hyprland"></a>
### Hyprland：ウィンドウとワークスペース

| キー | 操作 |
| --- | --- |
| Super+HJKL・矢印 | フォーカス移動 |
| Super+Shift+HJKL・矢印 | ウィンドウのリサイズ |
| Super+Enter / Super+Shift+Enter | 新しい端末を右 / 下へ分割 |
| Super+W | 現在のウィンドウを閉じる |
| **Super+Shift+W** | **現在のワークスペースの全ウィンドウを閉じる** |
| Super+Shift+F | 最大幅 / 約50%幅（バーを隠すfullscreenとは別） |
| Super+T | floating / tiling |
| Super+Shift+T | Scroll / Dwindleレイアウト切り替え |
| Super+E → HJKL・矢印 | 指定方向のウィンドウと交換 |
| Super+PageUp / PageDown | 前 / 次のウィンドウ |
| Super+Shift+PageUp / PageDown | 前 / 次のワークスペース |
| Super+数字・Tab・Shift+Tab | 既存のワークスペース指定・次・前 |
| Super+Ctrl+PageUp / PageDown | 前 / 次のモニター |
| Super+D / Super+Shift+D | デスクトップ表示 / Overview |
| Super+Ctrl+F | tiled fullscreen |
| Super+Ctrl+Shift+HJKL・矢印 | 指定方向へのウィンドウ移動 |

Super+Shift+Wは押した時点のワークスペース（special表示中はそのspecialワークスペース）のウィンドウだけに通常の終了を要求します。別ワークスペースは対象外で、閉じる途中にフォーカスが移っても対象を追加しません。強制killはしません。dwindleの分割は右/下をpreselectして起動し、scrollingの下分割は新しい端末を前の列へconsumeします。Super+Ctrl+Shift+方向の移動は通常ウィンドウを従来どおり動かし、フロート中は浮かせたまま指定方向へ50論理ピクセル移動します。Super+Shift+方向のリサイズも、フロート中はそのウィンドウ自身の幅・高さを50論理ピクセルずつ変更します。Scrollingの列幅やタイル同士のサイズ制限は適用しません。Super+Ctrl+方向のスワップは通常ウィンドウを従来どおり交換し、フロート中は方向の端にあるタイルウィンドウと場所を交換し、そのウィンドウを元のフロートの位置・サイズでフロート化します。

<a id="keys-wezterm"></a>
### WezTerm：端末ペイン・タブ・ワークスペース

| キー | 操作 |
| --- | --- |
| Ctrl+Alt+HJKL・矢印 | ペイン移動 |
| Ctrl+Alt+Shift+HJKL・矢印 | ペインのリサイズ |
| Ctrl+Alt+Enter / Ctrl+Alt+Shift+Enter | 右 / 下へ分割 |
| Ctrl+Alt+W / Ctrl+Alt+Shift+W | ペイン / タブを確認付きで閉じる |
| Ctrl+Alt+F / Ctrl+Alt+Shift+F | 端末履歴検索 / ペイン最大化・復元 |
| Ctrl+Alt+N / Ctrl+Alt+Shift+N | タブ / ウィンドウ作成 |
| Ctrl+Alt+Y / Ctrl+Alt+Shift+Y | Yaziを右ペインで開く / コピーモード |
| Ctrl+Alt+E → HJKL | 指定方向のペインと交換 |
| Ctrl+Alt+Tab / Ctrl+Alt+Shift+Tab | 次 / 前のタブ |
| Ctrl+Alt+PageUp / PageDown | 前 / 次のタブ |
| Ctrl+Alt+Shift+PageUp / PageDown | 前 / 次のワークスペース |
| Ctrl+Alt+1〜9 | タブ番号を指定 |
| Ctrl+Alt+G / Ctrl+Alt+Shift+G | ワークスペース一覧 / 作成 |
| Ctrl+Alt+R / Ctrl+Alt+Shift+R | タブ / ワークスペース改名 |
| Ctrl+Alt+P | コマンドパレット |
| Ctrl+Alt+, / Ctrl+Alt+Shift+, | 再読み込み / 設定ファイルを開く |
| Ctrl+Alt+= / - / 0 | フォント拡大 / 縮小 / リセット |
| Ctrl+Alt+U / Ctrl+Alt+Shift+U | 半透明 / 強い透過と元状態 |
| Ctrl+Alt+I / Ctrl+Alt+Shift+I | 右33%にHerdr / chat |
| Ctrl+Alt+Home / End | 履歴の先頭 / 末尾 |
| Ctrl+Insert / Shift+Insert | コピー / 貼り付け（Omarchyの転送先） |
| Ctrl+Shift+C / V | 慣用のコピー / 貼り付け |

テーマ用のCtrl+Alt+B / Ctrl+Alt+Shift+Bは廃止して未割当です。内側のNeovimのCtrl+B、HerdrのAlt+Bには影響しません。

交換ではネイティブ候補にHJKLの方向ラベルを表示します。タブの並べ替えはタブバーをドラッグします。コピーモードはhjkl、v/V、y、Enter、Escで操作します。T/Shift+Tは該当機能がないため未割当、Leaderは使いません。

<a id="keys-herdr"></a>
### Herdr：継続作業とエージェント

| キー | 操作 |
| --- | --- |
| Alt+HJKL・矢印 / Shift追加 | ペイン移動 / リサイズ |
| Alt+Enter / Alt+Shift+Enter | 右 / 下へ分割 |
| Alt+W / Alt+Shift+W | ペイン / タブを閉じる |
| Alt+F / Alt+Shift+F | 履歴検索 / ペイン最大化・復元 |
| Alt+T | 補助シェルpopupを開く / popupのプロンプトから閉じる |
| Alt+N / Alt+Shift+N | タブ / ワークスペース作成 |
| Alt+Y / Alt+Shift+Y | Yazi用の一時ペイン / コピーモード |
| Alt+E → HJKL・矢印 | 指定方向のペインと交換 |
| Alt+E → PageUp / PageDown | タブの並べ替え |
| Alt+Tab / Alt+Shift+Tab | 次 / 前のタブ（ペイン巡回から変更） |
| Alt+PageUp / PageDown | 前 / 次のタブ |
| Alt+Shift+PageUp / PageDown | 前 / 次のワークスペース |
| Alt+1〜9 | タブ番号を指定 |
| Alt+G / Alt+Shift+G | ワークスペース一覧 / worktree作成 |
| Alt+R / Alt+Shift+R / Alt+Shift+P | タブ / ワークスペース / ペイン改名 |
| Alt+D / Alt+Shift+D | detach / ワークスペース終了 |
| Alt+O / Alt+B | 通知の対象へ移動 / サイドバー |
| Alt+P / Alt+Shift+E | Goto / スクロールバックをエディターで開く |
| Alt+, / Alt+Shift+, / Alt+/ | 設定 / 再読み込み / ヘルプ |

Alt+Eが交換用Prefixです。通常の分割・作成・移動はPrefix不要です。Shift+Tは未割当です。Herdrでは既存設定どおり終了確認を無効にしています。

Herdrのpopupは入力を内部のアプリへ渡すため、popup専用ZshにAlt+Tの終了キーを設定しています。Alt+Tはプロンプトでシェルを終了して元の画面へ戻ります。別のツールを実行中は、そのツールを終了してプロンプトへ戻ってから使います。popupを隠して保持する機能ではなく、開き直すと新しいシェルになります。通常のZshにはAlt+Tを割り当てません。

<a id="keys-tmux"></a>
### tmux：Herdrと同じAlt層

| キー | 操作 |
| --- | --- |
| Alt+HJKL・矢印 / Shift追加 | ペイン移動 / リサイズ |
| Alt+Enter / Alt+Shift+Enter | 右 / 下へ分割 |
| Alt+W / Alt+Shift+W | ペイン / windowを閉じる（windowは確認付き） |
| Alt+F / Alt+Shift+F | 履歴検索 / ペイン最大化・復元 |
| Alt+T / Alt+Shift+T | 一時シェルpopup / 次のレイアウト |
| Alt+N / Alt+Shift+N | window / session作成 |
| Alt+Y / Alt+Shift+Y | Yazi用の一時ペイン / コピーモード |
| Alt+E → HJKL・矢印 | 指定方向のペインと交換 |
| Alt+E → PageUp / PageDown | windowの並べ替え |
| Alt+Tab / Alt+Shift+Tab | 次 / 前のwindow |
| Alt+PageUp / PageDown | 前 / 次のwindow |
| Alt+Shift+PageUp / PageDown | 前 / 次のsession |
| Alt+1〜9 | window番号を指定 |
| Alt+G | session一覧 |
| Alt+R / Alt+Shift+R | window / session改名 |
| Alt+D | detach |
| Ctrl+SpaceまたはCtrl+B → q / ? | 設定再読み込み / キー一覧 |

windowは他のツールのタブ、sessionはワークスペースに対応します。コピーモードではvで選択、yでコピーします。予備Prefix以外の日常操作は直接キーです。

<a id="keys-neovim"></a>
### Neovim：バッファ・ウィンドウ・タブページ

| キー | 操作 |
| --- | --- |
| Ctrl+HJKL・矢印 / Shift追加 | ウィンドウ移動 / リサイズ |
| Ctrl+Enter / Ctrl+Shift+Enter | 右 / 下へ分割 |
| Ctrl+W / Ctrl+Shift+W | ウィンドウ / タブページを閉じる（最後のタブならNeovim終了） |
| Ctrl+F / Ctrl+G | ファイル検索 / 内容grep |
| Ctrl+Shift+F | ウィンドウ最大化 / サイズ復元 |
| Ctrl+T | ToggleTermの同じフロート端末を表示・非表示 |
| Ctrl+N / Ctrl+Shift+N | 空バッファ / タブページ作成 |
| Ctrl+Y | Yazi。選択したファイルをNeovimで開く |
| Ctrl+E → HJKL・矢印 | 指定方向のウィンドウと交換 |
| Ctrl+Tab / Ctrl+Shift+Tab | 次 / 前のタブページ |
| Ctrl+PageUp / PageDown | 前 / 次のバッファ |
| Ctrl+Shift+PageUp / PageDown | 前 / 次のタブページ |
| Ctrl+1〜9 | タブページ番号を指定 |
| Ctrl+S / Ctrl+Shift+S | 保存 / 強制保存 |
| Ctrl+B / Ctrl+D | バッファ一覧 / Git差分 |
| F2 | LSP引数ヒント |
| Space f f/r/g/b/e | ファイル / 最近 / grep / バッファ / Yazi |
| Space w h/j/k/l、v/e/q/x | ウィンドウ移動・右分割・下分割・終了・交換の互換入口 |
| Space u c/h | Copilot / inlay hint |
| Space g l | Gitログ |
| - / :Yazi / :Oil | Yazi / Yazi / Oil |

テーマ用のSpace t t/lと`:Theme` / `:ThemeToggle` / `:ThemeList`は廃止しました。テーマはOmarchyから変更してください。

構造操作はNormal・Insert・Visual・Terminalで使います。検索はNormal・Insert・Visualです。Ctrl+Wは標準プレフィックスから直接closeに変更し、未保存変更は通常のquit/tabcloseが保護します。Ctrl+KのLSP上書きを除き移動を優先します。Tab/Shift+TabはNormalでバッファ移動、Insertで補完・スニペット。通常のy/d/p、レジスタ、/検索は維持します。Shift+Y/Shift+Tには独自機能を追加しません。

<a id="keys-yazi"></a>
### Yazi：ファイル操作とタブ

| キー | 操作 |
| --- | --- |
| Ctrl+HJKL・矢印 | 親 / 次 / 前 / 子へ移動 |
| Ctrl+Shift+HJKL・矢印 | プレビュー幅を縮小 / 拡大 |
| Ctrl+W | 現在のタブを閉じる。最後ならcwdを渡して終了 |
| Ctrl+Shift+W | 全タブを終了してcwdを渡す |
| Ctrl+F / Ctrl+G | fdでファイル名 / rgで内容検索 |
| Ctrl+Shift+F | プレビュー最大化 / 復元 |
| Ctrl+N | 現在のディレクトリでタブ作成 |
| Ctrl+Y | タブ一覧から選ぶ（Yaziは再帰起動しない） |
| Ctrl+E → PageUp / PageDown | タブを並べ替え |
| Ctrl+Tab / Ctrl+Shift+Tab | 次 / 前のタブ |
| Ctrl+PageUp / PageDown / Ctrl+1〜9 | 前 / 次 / 指定番号のタブ |
| PageUp / PageDown | プレビューを上 / 下へスクロール（テキストは半ページ） |
| Shift+PageUp / Shift+PageDown | 一覧を半ページ上 / 下へ移動 |
| 数字+j/k・↑/↓ | 指定数の項目を下 / 上へ移動（例：5j、12↓） |
| 数字+G / 数字+gg | 指定番号の項目へ移動（1始まり） |
| hjkl・矢印、/、f | 移動 / 一覧内検索 / フィルタ |
| y/d/p、Space/v | コピー・切り取り・貼り付け / 選択 |
| Enter / Shift+Enter | 開く / アプリ選択 |
| a/r/x/X | 作成 / 改名 / ゴミ箱 / 完全削除 |
| q/Q | cwdを渡して終了 / cwdを渡さず終了 |

ファイル一覧はdで切り取り、Dで切り取り登録を解除、xでゴミ箱へ移動、Xで完全削除です。DはYと同じunyankで、コピー登録も解除します。dはファイルを切り取り対象として登録し、pで貼り付けた時点で移動します。入力欄のd/xはVim標準の文字編集を維持します。

数字による移動は1〜9で開始し、途中の0も桁として扱います（10j等）。Escで取り消し、完了・取り消し後に数を持ち越しません。j/k・上下矢印はVim同様に先頭・末尾で止まり、折り返しません。数字なしのgg/Gは先頭/末尾です。素の数字1〜9によるタブ指定は廃止し、Ctrl+1〜9を使用します。カウントは上下移動とG/ggに対応し、Vimの演算子全般を追加するものではありません。PageUp/DownはYazi標準のseek ±5を使い、テキストでは表示領域の半ページ相当をスクロールします。動画などではスクロール単位がプレビュー形式に従います。

Yazi自身には独立した端末分割がないため、通常は外側のWezTerm/Herdr/tmuxで分割します。yazi.nvim内のCtrl+Enter/Shift追加は、選択ファイルをNeovimの右/下分割へ開きます。NeovimのCtrlキーは埋め込みYaziへ渡します。入力・選択・確認画面のCtrl+Wはその画面だけを閉じます。

Zshのyは終了時のディレクトリへ移動します。デスクトップのSuper+Yはyazi.desktop経由で起動し、終了後にその場所のシェルを開きます。

<a id="keys-zsh"></a>
### Zsh・fzf：プロンプトで使うアプリ層

| キー | 操作 |
| --- | --- |
| Ctrl+F | f関数：ファイルを検索して開く |
| Ctrl+G | g関数：内容を検索して該当行を開く |
| Ctrl+D | d関数：ディレクトリを検索して移動 |
| Ctrl+Y | y関数：Yaziを開き、最後のディレクトリへ移動 |
| Ctrl+R | fzf履歴検索 |
| Ctrl+W | 入力キャンセル / 通常の前景コマンドへSIGINT |
| Ctrl+Shift+W / exit | シェル終了 |
| Ctrl+L | 画面を消去して一覧表示 |
| Ctrl+Backspace / Ctrl+Delete | 前 / 後の単語削除 |
| Esc → Esc | 編集中の入力行を全削除 |
| Ctrl+Left / Right、Home / End | 単語移動、行頭 / 行末 |
| fzf内のCtrl+W / Esc | 検索を中断 |
| fzf内のPageUp / PageDown、Shift+Up / Down | プレビュー半ページ / 1行移動 |

f/g/d/y関数名はそのままです。ZLE widgetから呼び、編集中の入力を保ちながら戻れます。空プロンプトでCtrl+Dが先にEOF処理されないようignoreeofを設定します。Ctrl+DのEOF操作は検索へ変更し、Ctrl+T/Alt+Cのfzf標準入口は外します。fzfのAlt+矢印はマルチプレクサ層と衝突するため削除しました。グローバルなCtrl+Rによるgit一覧再読み込みも削除し、履歴検索へ統一します。

Ctrl+WはZLEのsend-breakに加え、TTYのintr文字を^Wへ設定します。通常のCtrl+Cと同じSIGINTで、強制killではありません。TTY割り込み文字はCtrl+CからCtrl+Wに変わります。ZLE入力中だけ拡張キーを要求し、Ctrl+Shift+Wと区別します。tmux内ではmodifyOtherKeys、WezTerm直下とHerdr内ではKitty形式で入力を要求します。ZLE側ではCSI-u形式と従来形式の両方を既存の編集widgetへ割り当て、矢印・Esc連打・Ctrl+Backspace/Delete・Home/Endなどを維持します。NumLock/CapsLockが付加する修飾値も扱うため、`;129u`や`;133u`などのキーコード断片が入力欄に残りません。Ctrl+Rのfzf履歴検索を含め、検索やYaziを開く間はシェル用の入力要求を解除し、戻ったら再有効にします。履歴検索ではEscによる中断と矢印による候補移動をそのまま使えます。独自raw入力のアプリはそのアプリのキーを使います。

<a id="keys-validation"></a>
### 競合・入力転送・確認方法

- Fcitx5の英単語補完（Hint Trigger / One Time Hint Trigger）は起動キーを空にして無効化しています。既定のCtrl+Alt+H/JはWezTermのペイン移動と競合するためです。日本語入力の切り替えは従来どおり使えます。
- Herdr/tmuxは同じAlt層です。ネストすると外側が先に受け取るため、通常はどちらか一方を使います。tmuxには予備Prefixを残しています。
- Alt+Shift+Tabの従来形式はHerdrで認識されない場合があるため、WezTermがAlt+F9へ変換し、Herdr/tmuxで前のタブ/windowへ移動します。Ctrl+Tab系は各アプリへ渡し、修飾なしTabは既存の補完などに使います。
- HerdrのパーサーはPageUp/Downをキー名として受け付けません。WezTermがAlt+PageUp/DownをAlt+F5/F6、Shift追加をAlt+F7/F8へ変換し、tmuxも同じ内部キーを受け付けます。Herdrのヘルプには内部キー名が表示されます。
- Alt+FはWezTermがAlt+Shift+Yを送り、コピー画面の表示を確認してから/を送ってHerdr/tmuxの履歴検索を開きます。非同期の画面切り替え前に/がシェルへ届くことを避けています。WezTerm以外ではHerdrのAlt+Shift+Y → /を使えます。
- 旧Qによる終了、Zによる最大化、Tによるタブ作成、Shift+Tのタブ改名、Shift+Yのworktree作成、Shift+PageUp/Downの並べ替えを新体系へ移しました。Ghosttyは変更対象外です。
- Ctrl+Enter、Ctrl+Shift+文字などは端末側の拡張キー対応が必要です。WezTermのKittyキーボードプロトコル、tmuxのextended-keysを有効にしています。

1. READMEを更新してから設定を変更する。
2. hyprctl reload / configerrors、wezterm show-keys、herdr config check、隔離tmuxサーバー、Neovim/YaziとZshのPTYで確認する。
3. WezTerm直下およびHerdr/tmux経由の入力を確認する。ワークスペース内の一括終了は通常セッションで実行せず、対象範囲と通常の終了要求だけを検証する。
4. 変更ファイルだけchezmoi addし、対象のdiffとソース一致を確認する。ログ・セッション・ソケット・バックアップは同期しない。

HerdrのCLIと実行中サーバーの版が違う場合は、サーバーを終了せず同じ実行バイナリでreloadします。Neovim/Yazi/Zshは新しいインスタンスから新設定を使用してください。

<a id="maintenance"></a>
## 10. 更新・編集・再読み込み

### 上流の変更を確認して取り込む

```bash
chezmoi cd
git status
# ローカル変更がある場合は、先に保存・commitなどを行う
git pull --ff-only
chezmoi diff
chezmoi apply --dry-run --verbose
chezmoi apply
```

`git pull` は管理元を更新し、`chezmoi apply` がホームへ反映します。`chezmoi update` でも取得と適用をまとめられます。どちらも保存した選択を使い、導入処理は実行しません。新たな依存パッケージも導入する場合は `install.sh` を再実行します。

Neovimの固定リビジョンを揃える場合は `:Lazy restore`、自分でプラグインを更新する場合は `:Lazy update` を使います。Sheldonの更新は `zsh-plugin-update` です。

`chezmoi apply --force` は確認を省いて上書きするので、通常の更新手順には含めていません。

### 実ファイルを編集した場合

```bash
# 例：利用中の設定を編集して動作を確認した後
chezmoi add ~/.config/omarchy/plugins/jeebis.bar/AnimationTiming.js
chezmoi diff
```

バインドを変更した場合は、[キーバインド一覧](#keybindings)も同時に更新してください。

`chezmoi add` は実ファイルを管理元に取り込む操作です。GitHubへの公開は別途commit / pushが必要です。意図しない設定や認証情報を混ぜないよう、対象ファイルを指定します。

### 管理元を編集した場合

```bash
chezmoi edit ~/.config/wezterm/wezterm.lua
chezmoi diff
chezmoi apply --exclude=scripts ~/.config/wezterm/wezterm.lua
```

### アプリの再読み込み

| 対象 | 反映方法 |
| --- | --- |
| Omarchy `shell.json`・プラグインのQML / JS / manifest | 通常は保存で再読み込み。反映しなければ `omarchy restart shell` |
| 共通 `AnimationTiming.js` | `omarchy restart shell` で全ウィジェットを読み直す |
| Hyprland | `hyprctl reload` 後、`hyprctl configerrors` で確認 |
| Ghostty（旧構成の参考） | 新しいウィンドウで確認。Omarchy経由では `omarchy restart terminal` |
| Zsh | 新しいシェルを起動、または `source ~/.zshrc` |
| Neovim・Yazi | アプリを再起動 |
| WezTerm | 自動再読み込み、またはCtrl+Shift+,。新規ウィンドウでも確認 |
| Herdr | `herdr config check`後、実行中なら`herdr server reload-config`、未起動なら次回起動 |
| systemdユーザーサービス | `systemctl --user daemon-reload` 後、対象サービスを再起動 |

`omarchy restart shell` はバーだけでなくshell全体を再起動し、開いていたパネルも閉じます。

<a id="troubleshooting"></a>
## 11. トラブルシューティングと復元

| 症状 | 確認すること |
| --- | --- |
| 初回導入でアプリが揃わない | 導入プランの選択、パッケージマネージャーのエラーを確認。`--configure-only` は導入しない。修正後に再実行 |
| 設定を編集したのに反映されない | 管理元と実ファイルのどちらを編集したか。`chezmoi diff` と対象アプリの再読み込み |
| バーが起動しない | Omarchy shellの存在、`shell.json` のIDとプラグイン、共通JSファイルの配置を確認 |
| 一つのワークスペースでドットが出ない | 通常は仕様。2つ以上の実ワークスペースで確認 |
| フォントやアイコンが崩れる | `--fonts` の選択と `fc-match 'HackGen35 Console NF'` で確認 |
| ZshでCLIツールが見つからない | `--cli` で公式パッケージを導入したか確認。新しいシェルでPATHを確認 |
| PDF・フォルダが開けない | `xdg-mime query default application/pdf` / `xdg-mime query default inode/directory`、対象アプリ・desktopファイル・`xdg-terminal-exec` の存在 |
| `Super+Y` でYaziが起動しない | `--files` の選択、`gtk-launch yazi`、`xdg-terminal-exec` の存在を確認 |
| Copilot・LSPが動かない | lazy.nvimのimport、`:Lazy` / `:checkhealth`、Node.js・認証・各言語サーバーを確認 |
| rcloneが起動を繰り返す | remote名・認証・実行パス・FUSEを確認。`journalctl --user -u rclone-gdrive.service -b` などでログを見る |

不要なrcloneサービスを止める場合：

```bash
systemctl --user disable --now rclone-gdrive.service rclone-onedrive.service
```

復元するときは、先に関連サービスを止め、導入前のバックアップから該当ファイルを戻します。元からなかったファイルは今回配置した対象を確認して取り除きます。chezmoiの管理元を削除するだけでは、適用済みファイルやシステム変更は戻りません。以前のログインシェル・ロケールも必要に応じて復元してください。lingerを有効化した場合は元の状態も復元してください。

Omarchyのrefresh系コマンドは既定設定への復元であり、導入前の自分の設定へ戻す操作とは異なります。

<a id="screenshots"></a>
## 12. スクリーンショット

実機のスクリーンショットは準備中です。掲載画像は同じテーマ・フォント・倍率で揃えると、設定との対応が伝わりやすくなります。

| 画像 | 撮影する場面 | 伝えたいこと |
| --- | --- | --- |
| デスクトップ全体 | 2つ以上のワークスペースを作り、WezTerm・Neovimなどを開いた通常の作業状態 | バー・余白・配色を含む全体像 |
| バーの展開状態 | アプリ島またはAgent島にホバーし、アイコン・ボタンが展開した状態 | 自動で隠れる島の使い方 |
| ウィジェット | カレンダー・電源パネル・通知履歴をそれぞれ開く | パネルの表示内容と役割 |
| Overview | 複数のウィンドウを開き、`Super + Shift + D` で一覧表示 | ワークスペースとウィンドウの切り替え |
| プロンプト | 公開用のGitリポジトリで通常時、`false` の実行後、`sleep 3` の実行後 | 顔・色・Git表示の変化 |
| Neovim・Yazi | サンプルコードと検索画面、画像またはPDFを選んだプレビュー | エディタとファイル管理の見た目 |

個人名・メール・通知本文・アカウント・非公開ファイル名・認証情報が写らないサンプル環境で撮影してください。アプリの起動・終了アニメーションは、静止画に加えて短い動画があると伝わりやすくなります。

<a id="references"></a>
## 13. 参考・謝辞・ライセンス

構成の説明、導入前の確認、見た目の紹介、更新手順の整理にあたり、以下のREADMEを参考にしています。各プロジェクトの導入コマンドをこのリポジトリで実行する必要はありません。

- [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)：対象範囲・機能・スクリーンショットを分けた紹介。
- [mathiasbynens/dotfiles](https://github.com/mathiasbynens/dotfiles)：fork・設定の確認と、個人設定を見直して導入する方針。

利用している基盤・ツール：

- [chezmoi公式ドキュメント](https://www.chezmoi.io/) / [apply](https://www.chezmoi.io/reference/commands/apply/) / [.chezmoiignore](https://www.chezmoi.io/reference/special-files/chezmoiignore/)
- [Omarchy](https://omarchy.org/) / [Hyprland](https://hypr.land/) / [Quickshell](https://quickshell.org/)
- [Sheldon](https://github.com/rossmacarthur/sheldon) / [Neovim](https://neovim.io/) / [Yazi](https://yazi-rs.github.io/)

カスタムプラグインにはOmarchy標準プラグインを元にしたものや、第三者のコードを含むものがあります。Overviewのクレジット・ライセンスは収録ディレクトリの [README](dot_config/omarchy/plugins/jeebis.overview/README.md) と [LICENSE](dot_config/omarchy/plugins/jeebis.overview/LICENSE) を確認してください。その他の同梱テーマ・プラグインも各ライセンスに従います。リポジトリ直下の統一ライセンスファイルは現状なく、全体に同じライセンスが適用されるとは限りません。

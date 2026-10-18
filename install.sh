#!/usr/bin/env bash
# Omarchy / Arch installer. All choices are collected before making changes.
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
config_home=${XDG_CONFIG_HOME:-$HOME/.config}
state_home=${XDG_STATE_HOME:-$HOME/.local/state}
profile="$config_home/chezmoi/dotfiles.json"
non_interactive=false
dry_run=false
configure_only=false
preset=custom
keys=(settings packages omarchy personalize japanese bar hyprland cli neovim ghostty files aur latex rclone change_shell downloads fonts mozkey rustup vscode wezterm mime cloud_mounts linger neovim_latest)
declare -A choices=()
git_name=''
git_email=''
git_name_set=false
git_email_set=false
unset DOTFILES_PROFILE

usage() {
  cat <<'HELP'
Usage: bash install.sh [options]

Three grouped questions cover settings, packages and Japanese support.
Per-feature choices use saved/default values; --no-NAME excludes a feature.

  --settings            Overwrite/sync selected dotfiles as a group (default: yes)
  --packages            Install selected tools as a group (default: yes)
  --omarchy             Use the existing Omarchy desktop (auto-detected default)
  --personalize         Configure Git for the current user; never copy author identity
  --git-name NAME       Git display name (default: existing name, then login name)
  --git-email EMAIL     Git email (default: existing email; empty means omit)
  --cli                 Install CLI tools + Zsh/Sheldon/bat settings (default: yes)
  --neovim              Neovim settings; install binary only if absent (default: yes)
  --ghostty             Optional legacy Ghostty binary only; no config sync (default: no)
  --files               Yazi + Zathura and preview tools/settings (default: yes)
  --bar                 Omarchy shell/bar/plugins (default: Omarchy selection)
  --hyprland            Hyprland settings including monitors/keys (default: yes)
  --japanese            Fcitx5 + Japanese system locale (default: yes)
  --downloads           Install curl + wget (default: yes)
  --fonts               Sync bundled HackGen Nerd Fonts (default: yes)
  --mozkey              Install Mozkey + original key/roman settings (default: --japanese)
  --rustup              Install Rustup + stable toolchain (default: --neovim)
  --vscode              Sync the original VS Code settings (default: yes)
  --wezterm             Install WezTerm + sync its settings (default: yes)
  --mime                Sync original default-app associations (default: yes)
  --cloud-mounts        Activate authenticated rclone mounts (requires --rclone)
  --linger              Keep user services alive after logout (requires --cloud-mounts)
  --neovim-latest       Use upstream's latest tarball instead of the distro binary
  --preset owner        Defaults for recreating the author's full setup
  --aur                 Prefer AUR for extras; bootstrap yay if needed (default: no)
  --latex               TeX Live + latexmk settings (default: yes)
  --rclone              Install rclone + sync service files (activation is separate)
  --change-shell        Change login shell to /bin/zsh (requires --cli; default: yes)
  --non-interactive     Skip grouped questions and confirmation; sudo may need credentials
  --configure-only      Save choices; do not install packages or apply dotfiles
  --dry-run             Show plan and chezmoi preview; do not save/install/apply
  -h, --help            Show this help

Examples:
  bash install.sh
  bash install.sh --omarchy --no-hyprland --dry-run
  bash install.sh --non-interactive --omarchy --cli --bar --no-japanese
HELP
}
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

while (($#)); do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --non-interactive) non_interactive=true ;;
    --dry-run) dry_run=true ;;
    --configure-only) configure_only=true ;;
    --preset)
      (($# >= 2)) || fail '--preset requires owner or custom'
      [[ $2 == owner || $2 == custom ]] || fail 'Unknown preset'
      preset=$2; shift ;;
    --git-name|--git-email)
      (($# >= 2)) || fail "$1 requires a value"
      case "$1" in --git-name) git_name=$2; git_name_set=true ;; --git-email) git_email=$2; git_email_set=true ;; esac
      shift ;;
    --*)
      key=${1#--}; value=true
      if [[ $key == no-* ]]; then key=${key#no-}; value=false; fi
      key=${key//-/_}
      [[ " ${keys[*]} " == *" $key "* ]] || fail "Unknown option: $1"
      choices[$key]=$value ;;
    *) fail "Unexpected argument: $1" ;;
  esac
  shift
done

command -v python3 >/dev/null || fail 'Python 3 is required (sudo pacman -S --needed python)'
check_destination() {
  if command -v chezmoi >/dev/null; then
    destination=$(chezmoi --source "$repo" dump-config --format=json | python3 -c 'import json,sys; print(json.load(sys.stdin)["destDir"])')
    [[ $destination == "$HOME" ]] || fail 'chezmoi destination must equal HOME for this installer'
  fi
}
check_destination
# A profile is data, never executable shell input. Validate before reading it.
if [[ -f $profile ]]; then
  python3 - "$profile" <<'PY'
import json, sys
p = json.load(open(sys.argv[1]))
assert p.get('version') == 1, 'Unsupported profile version'
for k, v in p.items():
    if k not in ('version', 'git_name', 'git_email'):
        assert type(v) is bool, f'Invalid boolean: {k}'
for k in ('git_name', 'git_email'):
    assert isinstance(p.get(k, ''), str), f'Invalid string: {k}'
PY
fi
saved() {
  python3 - "$profile" "$1" "$2" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1])
v = json.loads(p.read_text()).get(sys.argv[2], sys.argv[3]) if p.exists() else sys.argv[3]
print(str(v).lower() if isinstance(v, bool) else v)
PY
}
choose() {
  local key=$1 question=$2 default=$3 answer
  [[ -v choices[$key] ]] && return 0
  if [[ $preset != owner ]]; then default=$(saved "$key" "$default"); fi
  if $non_interactive; then choices[$key]=$default; return; fi
  [[ -t 0 ]] || fail 'Use --non-interactive or run in a terminal to answer setup questions'
  while true; do
    if [[ $default == true ]]; then printf '%s [Y/n]: ' "$question"; else printf '%s [y/N]: ' "$question"; fi
    read -r answer || fail 'Input closed; no changes made'
    case "$answer" in
      '') choices[$key]=$default; return ;;
      [Yy]|[Yy][Ee][Ss]) choices[$key]=true; return ;;
      [Nn]|[Nn][Oo]) choices[$key]=false; return ;;
    esac
  done
}

resolve() {
  local key=$1 default=$2
  [[ -v choices[$key] ]] && return 0
  if [[ $preset != owner ]]; then default=$(saved "$key" "$default"); fi
  choices[$key]=$default
}

detected=false
if command -v omarchy >/dev/null && [[ -d ${OMARCHY_PATH:-/usr/share/omarchy} ]]; then detected=true; fi
resolve omarchy "$detected"
choose settings 'このDotfilesで既存設定を上書きしますか？（事前にバックアップします）' true
choose packages 'アプリ・CLI・フォントをまとめて導入しますか？' true
choose japanese '日本語入力・日本語ロケールも設定しますか？' true
resolve personalize true
resolve bar "${choices[omarchy]}"
resolve hyprland "${choices[omarchy]}"
resolve cli true
resolve neovim true
# Ghostty is a legacy install-only option; do not inherit an old enabled profile.
[[ -v choices[ghostty] ]] || choices[ghostty]=false
resolve wezterm true
resolve files true
resolve downloads true
resolve fonts true
if ! ${choices[japanese]} && [[ ! -v choices[mozkey] ]]; then choices[mozkey]=false; fi
resolve mozkey "${choices[japanese]}"
resolve rustup "${choices[neovim]}"
resolve vscode true
resolve mime true
resolve neovim_latest false
resolve aur false
resolve latex true
resolve rclone true
resolve cloud_mounts false
resolve linger false
resolve change_shell true

if ${choices[personalize]}; then
  if ! $git_name_set; then
    git_name=$(saved git_name "$(git config --global user.name 2>/dev/null || id -un)")
    [[ -n $git_name ]] || git_name=$(id -un)
  fi
  if ! $git_email_set; then git_email=$(saved git_email "$(git config --global user.email 2>/dev/null || true)"); fi

fi
[[ $git_name != *$'\n'* && $git_name != *$'\r'* && $git_email != *$'\n'* && $git_email != *$'\r'* ]] || fail 'Git identity must be a single line'
${choices[settings]} && ${choices[change_shell]} && ! ${choices[cli]} && fail '--change-shell requires --cli'
${choices[packages]} && ${choices[neovim_latest]} && ! ${choices[neovim]} && fail '--neovim-latest requires --neovim'
${choices[settings]} && ${choices[cloud_mounts]} && ! ${choices[rclone]} && fail '--cloud-mounts requires --rclone'
${choices[settings]} && ${choices[linger]} && ! ${choices[cloud_mounts]} && fail '--linger requires --cloud-mounts'
if ${choices[omarchy]}; then
  command -v omarchy >/dev/null && [[ -d ${OMARCHY_PATH:-/usr/share/omarchy} ]] || fail '--omarchy requires an existing Omarchy installation'
fi
if ${choices[settings]} && { ${choices[bar]} || ${choices[hyprland]}; }; then
  ${choices[omarchy]} || fail 'Bar/Hyprland settings require --omarchy'
  command -v omarchy >/dev/null && [[ -d ${OMARCHY_PATH:-/usr/share/omarchy} ]] || fail 'Install Omarchy before selecting its desktop settings'
fi

# Official packages first; named upstream installers preserve unavailable extras.
packages=()
aur_packages=()
extras=()
add_package() { packages+=("$1"); }
command -v chezmoi >/dev/null || add_package chezmoi
command -v git >/dev/null || add_package git
if ${choices[downloads]}; then packages+=(curl wget); fi
if ${choices[personalize]}; then packages+=(git git-delta); fi
if ${choices[cli]}; then
  packages+=(git zsh sheldon eza bat git-delta dust fzf zoxide ripgrep fd unzip stow)
fi
if ${choices[neovim]}; then
  if ${choices[neovim_latest]}; then extras+=(neovim)
  else command -v nvim >/dev/null || add_package neovim; fi
  packages+=(base-devel)
  if ! ${choices[rustup]}; then command -v cargo >/dev/null || add_package rust; fi
fi
if ${choices[ghostty]}; then
  command -v ghostty >/dev/null || add_package ghostty
fi
plan_extra() {
  local package=$1 installer=$2
  if command -v pacman >/dev/null && pacman -Q "$package" &>/dev/null; then return; fi
  if command -v pacman >/dev/null && pacman -Si "$package" &>/dev/null; then
    add_package "$package"
  elif ${choices[aur]}; then
    aur_packages+=("$package")
  else
    extras+=("$installer")
  fi
}
if ${choices[fonts]}; then packages+=(fontconfig); fi
if ${choices[files]}; then packages+=(yazi zathura zathura-pdf-mupdf ffmpeg 7zip jq poppler imagemagick); fi
if ${choices[japanese]} || ${choices[mozkey]}; then
  packages+=(fcitx5 fcitx5-gtk fcitx5-qt fcitx5-configtool)
  if ${choices[mozkey]}; then
    packages+=(base-devel curl)
    plan_extra mozkey-ibg-bin mozkey
  else
    add_package fcitx5-mozc
  fi
fi
if ${choices[rustup]}; then
  add_package curl
  # Do not replace/conflict with an existing system rust package.
  if ! command -v rustup >/dev/null && ! pacman -Q rust &>/dev/null; then add_package rustup; fi
  extras+=(rustup)
fi
if ${choices[wezterm]}; then command -v wezterm >/dev/null || add_package wezterm; fi
if ${choices[latex]}; then packages+=(texlive-bin texlive-basic texlive-latex texlive-latexrecommended texlive-binextra texlive-langjapanese texlive-mathscience); fi
if ${choices[rclone]}; then packages+=(rclone fuse3); fi
if ((${#aur_packages[@]})); then
  if ! command -v yay >/dev/null; then packages+=(base-devel git); extras=(yay "${extras[@]}"); fi
fi
if ! $configure_only && ${choices[packages]} && [[ " ${extras[*]} " == *' mozkey '* ]] && [[ $(python3 -c 'import platform; print(platform.machine())') != x86_64 ]]; then
  fail 'The upstream Mozkey Arch payload is x86_64 only'
fi
# Deduplicate; --needed also protects against a concurrent installer.
missing=()
declare -A seen=()
for pkg in "${packages[@]}"; do
  [[ -v seen[$pkg] ]] && continue
  seen[$pkg]=1
  if ! command -v pacman >/dev/null || ! pacman -Q "$pkg" &>/dev/null; then missing+=("$pkg"); fi
done
missing_aur=()
for pkg in "${aur_packages[@]}"; do
  if ! command -v pacman >/dev/null || ! pacman -Q "$pkg" &>/dev/null; then missing_aur+=("$pkg"); fi
done
if ! $configure_only && ${choices[packages]}; then
  command -v pacman >/dev/null || fail 'This installer supports Omarchy/Arch Linux with pacman only'
fi

if ! $configure_only && ! ${choices[packages]}; then command -v chezmoi >/dev/null || fail 'chezmoi is required with --no-packages'; fi

printf '\n導入プラン（変更前）\n'
printf '  設定上書き=%s / ツール導入=%s / 日本語=%s\n' "${choices[settings]}" "${choices[packages]}" "${choices[japanese]}"
printf '  Omarchy=%s / WezTerm=%s\n' "${choices[omarchy]}" "${choices[wezterm]}"
excluded=()
for key in cli neovim wezterm files downloads fonts mozkey rustup vscode mime bar hyprland latex rclone change_shell; do
  ${choices[$key]} || excluded+=("$key")
done
printf '  個別の除外: %s\n' "${excluded[*]:-(なし)}"
printf '  Git name/email: %s / %s\n' "$git_name" "$git_email"
if ${choices[packages]}; then
  printf '  不足している公式パッケージ: %s\n' "${missing[*]:-(なし)}"
  printf '  不足しているAURパッケージ: %s\n' "${missing_aur[*]:-(なし)}"
  printf '  専用インストーラー: %s\n' "${extras[*]:-(なし)}"
else
  printf '  ツールの導入は行いません。\n'
fi
printf '  選択の保存先: %s\n' "$profile"

# Only a temporary file is created for a dry run; user settings stay untouched.
tmp_profile=$(mktemp)
trap 'rm -f -- "$tmp_profile"' EXIT
args=()
for key in "${!choices[@]}"; do args+=("$key=${choices[$key]}"); done
python3 - "$tmp_profile" "$git_name" "$git_email" "${args[@]}" <<'PY'
import json, sys
p = dict(version=1, git_name=sys.argv[2], git_email=sys.argv[3])
p.update((k, v == 'true') for k, v in (a.split('=', 1) for a in sys.argv[4:]))
with open(sys.argv[1], 'w') as f: json.dump(p, f, ensure_ascii=False, indent=2)
PY
if $dry_run; then
  if ! $configure_only; then
    if command -v chezmoi >/dev/null; then
      DOTFILES_PROFILE=$tmp_profile chezmoi --source "$repo" apply --dry-run --verbose --exclude=scripts
    else
      printf 'chezmoiは導入予定です。現在は未導入のため設定プレビューを省略します。\n'
    fi
  fi
  exit 0
fi
if ! $non_interactive; then
  printf '\nこの内容で開始しますか？ [y/N]: '
  read -r answer || fail 'Input closed'
  [[ $answer == [Yy] || $answer == [Yy][Ee][Ss] ]] || { printf '中止しました。変更はありません。\n'; exit 0; }
fi

# Preflight cloud credentials before changing packages/configuration.
if ${choices[settings]} && ${choices[cloud_mounts]} && ! $configure_only; then
  command -v rclone >/dev/null || fail 'Authenticate gdrive: and onedrive: using rclone config first'
  remotes=$(rclone listremotes)
  for remote in gdrive: onedrive:; do
    grep -Fxq "$remote" <<< "$remotes" || fail "Missing rclone remote: $remote (run rclone config first)"
  done
  for mount in "$HOME/GoogleDrive" "$HOME/OneDrive"; do
    if mountpoint -q "$mount"; then continue; fi
    if [[ -d $mount ]] && [[ -n $(find "$mount" -mindepth 1 -maxdepth 1 -print -quit) ]]; then fail "Mount directory is not empty: $mount"; fi
  done
fi

if ! $configure_only && ${choices[packages]}; then
  if ((${#missing[@]})); then
    if ${choices[omarchy]}; then omarchy pkg add "${missing[@]}"
    else
      confirm=(); $non_interactive && confirm+=(--noconfirm)
      sudo pacman -S --needed "${confirm[@]}" "${missing[@]}"
    fi
  fi
  # Bootstrap yay before the optional AUR transaction.
  for extra in "${extras[@]}"; do
    if [[ $extra == yay ]]; then
      extra_flags=(); $non_interactive && extra_flags+=(--non-interactive)
      python3 "$repo/scripts/install-extras.py" yay "${extra_flags[@]}"
    fi
  done
  if ((${#missing_aur[@]})); then
    if ${choices[omarchy]}; then omarchy pkg aur add "${missing_aur[@]}"
    else
      confirm=(); $non_interactive && confirm+=(--noconfirm)
      yay -S --needed "${confirm[@]}" "${missing_aur[@]}"
    fi
  fi
  for extra in "${extras[@]}"; do
    [[ $extra == yay ]] && continue
    extra_flags=(); $non_interactive && extra_flags+=(--non-interactive)
    python3 "$repo/scripts/install-extras.py" "$extra" "${extra_flags[@]}"
  done
  command -v chezmoi >/dev/null || fail 'chezmoi installation did not provide its command'
  check_destination
fi

# Back up only selected files, never entire .config/.local trees.
mkdir -p -- "$state_home/dotfiles/backups"
backup=$(mktemp -d "$state_home/dotfiles/backups/$(date +%Y%m%d-%H%M%S).XXXXXX")
if [[ -f $profile ]]; then cp -p -- "$profile" "$backup/profile.json"; fi
if ! $configure_only; then
  DOTFILES_PROFILE=$tmp_profile chezmoi --source "$repo" managed --include=files,symlinks --path-style=relative --nul-path-separator > "$backup/managed.paths"
  python3 - "$HOME" "$backup" <<'PY'
import json, pathlib, shutil, sys
home, backup = map(pathlib.Path, sys.argv[1:])
paths = [p.decode() for p in (backup/'managed.paths').read_bytes().split(b'\0') if p]
manifest = []
for rel in paths:
    src = home/rel
    dst = backup/'files'/rel
    exists = src.exists() or src.is_symlink()
    manifest.append({'path': rel, 'existed': exists})
    if exists:
        dst.parent.mkdir(parents=True, exist_ok=True)
        if src.is_symlink(): dst.symlink_to(src.readlink())
        elif src.is_dir(): raise SystemExit(f'Expected file, found directory: {src}')
        else: shutil.copy2(src, dst)
(backup/'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
PY
fi
mkdir -p -- "$(dirname -- "$profile")"
install -m 600 "$tmp_profile" "$profile.new.$$"
mv -f -- "$profile.new.$$" "$profile"
printf '\nバックアップ: %s\n' "$backup"
if $configure_only; then printf '選択を保存しました。chezmoi diffで確認後、chezmoi applyで適用できます。\n'; exit 0; fi
chezmoi --source "$repo" apply --force --exclude=scripts
if ${choices[settings]} && ${choices[fonts]} && command -v fc-cache >/dev/null; then
  fc-cache -f "$HOME/.local/share/fonts/HackGen"
fi

if ${choices[settings]} && ${choices[japanese]}; then
  sudo sed -i 's/^#[[:space:]]*ja_JP.UTF-8 UTF-8/ja_JP.UTF-8 UTF-8/' /etc/locale.gen
  sudo locale-gen
  sudo localectl set-locale LANG=ja_JP.UTF-8
fi
if ${choices[settings]} && ${choices[change_shell]}; then
  grep -Fxq /bin/zsh /etc/shells || printf '/bin/zsh\n' | sudo tee -a /etc/shells >/dev/null
  if [[ $(getent passwd "$(id -un)" | cut -d: -f7) != /bin/zsh ]]; then sudo chsh -s /bin/zsh "$(id -un)"; fi
fi
if ${choices[settings]} && ${choices[cloud_mounts]}; then
  mkdir -p -- "$HOME/GoogleDrive" "$HOME/OneDrive"
  systemctl --user daemon-reload
  systemctl --user enable --now rclone-gdrive.service rclone-onedrive.service
fi
if ${choices[settings]} && ${choices[linger]}; then sudo loginctl enable-linger "$(id -un)"; fi
printf '\n完了しました。新しいターミナルで確認してください。日本語/ログインシェル変更時は再ログインが必要です。\n'
printf 'バー: omarchy restart shell / Hyprland: hyprctl reload && hyprctl configerrors\n'

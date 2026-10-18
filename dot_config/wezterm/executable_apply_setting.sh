#!/usr/bin/env bash
set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
target_dir=${1:-}

if [[ -z "$target_dir" ]]; then
  if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    # Resolve the current Windows user instead of assuming a user name.
    windows_home=$(powershell.exe -NoProfile -NonInteractive -Command '[Environment]::GetFolderPath("UserProfile")' | tr -d '\r')
    [[ -n "$windows_home" ]] || { echo 'Could not resolve the Windows home directory.' >&2; exit 1; }
    target_dir="$(wslpath -u "$windows_home")/.config/wezterm"
  else
    echo 'Linux uses this configuration directly; no copy is needed.'
    echo 'To copy elsewhere: apply_setting.sh /path/to/wezterm/config'
    exit 0
  fi
fi

mkdir -p -- "$target_dir"
target_dir=$(cd -- "$target_dir" && pwd)
if [[ "$source_dir" == "$target_dir" ]]; then
  echo 'The configuration is already in the target directory.'
  exit 0
fi
cp -- "$source_dir"/*.lua "$target_dir/"
palette="$HOME/.local/state/omarchy/current/theme/wezterm.toml"
[[ -f "$palette" ]] || palette="$source_dir/omarchy.toml"
cp -- "$palette" "$target_dir/omarchy.toml"
echo "Applied WezTerm configuration to: $target_dir"

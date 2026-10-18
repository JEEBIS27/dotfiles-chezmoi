#!/bin/bash
set -euo pipefail

# Serialize the read/select/apply sequence when the shortcut is pressed rapidly.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/jeebis-theme-cycle-${UID}.lock"
flock 9

config_home=${XDG_CONFIG_HOME:-$HOME/.config}
state_home=${XDG_STATE_HOME:-$HOME/.local/state}
omarchy_path=${OMARCHY_PATH:-/usr/share/omarchy}
themes=(tokyonight kanagawa catppuccin)
labels=(Tokyonight Kanagawa Catppuccin)

# Use the personal Tokyonight theme when present, otherwise Omarchy's stock one.
if [[ ! -d "$config_home/omarchy/themes/tokyonight" && ! -d "$omarchy_path/themes/tokyonight" ]]; then
  themes[0]=tokyo-night
fi

current=$(cat "$state_home/omarchy/current/theme.name" 2>/dev/null || true)
case "$current" in
  tokyonight|tokyo-night) index=1 ;;
  kanagawa|kanagawa-wave) index=2 ;;
  *) index=0 ;;
esac
next=${themes[$index]}
label=${labels[$index]}

if [[ ! -d "$config_home/omarchy/themes/$next" && ! -d "$omarchy_path/themes/$next" ]]; then
  omarchy notification send -u normal -t 4000 \
    'テーマを切り替えられません' "テーマが見つかりません: $label"
  exit 1
fi

if omarchy theme set "$next" && [[ $(cat "$state_home/omarchy/current/theme.name") == "$next" ]]; then
  omarchy notification send -u normal -t 2500 \
    "テーマ: $label" 'Tokyonight → Kanagawa → Catppuccin'
else
  omarchy notification send -u normal -t 4000 \
    'テーマの切り替えに失敗しました' "$label"
  exit 1
fi

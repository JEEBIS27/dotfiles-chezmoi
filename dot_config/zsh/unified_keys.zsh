# Application layer: Ctrl, alongside Neovim and Yazi.
# Source AFTER plugin keymaps so fzf's defaults cannot override these widgets.
[[ -o interactive ]] || return
# ZLE otherwise exits on the TTY EOF character before looking up its widget.
setopt ignoreeof

autoload -Uz add-zsh-hook
__unified_tty_interrupt() {
  [[ -t 0 ]] && command stty intr '^W' werase undef 2>/dev/null
  return 0
}
add-zsh-hook precmd __unified_tty_interrupt
add-zsh-hook preexec __unified_tty_interrupt
__unified_tty_interrupt

__unified_files() { zle -I; __unified_zle_end; f; __unified_zle_begin; zle reset-prompt; }
__unified_grep() { zle -I; __unified_zle_end; g; __unified_zle_begin; zle reset-prompt; }
__unified_dirs() { zle -I; __unified_zle_end; d; __unified_zle_begin; zle reset-prompt; }
__unified_yazi() { zle -I; __unified_zle_end; y; __unified_zle_begin; zle reset-prompt; }
# A ZLE widget does not trigger line-finish while its child fzf runs.
# Suspend the shell's keyboard protocol and restore it even on interruption.
__unified_history() {
  __unified_zle_end
  {
    zle fzf-history-widget
  } always {
    __unified_zle_begin
  }
}
__unified_exit() { zle -I; exit; }
zle -N unified-files __unified_files
zle -N unified-grep __unified_grep
zle -N unified-dirs __unified_dirs
zle -N unified-yazi __unified_yazi
zle -N unified-exit __unified_exit
zle -N unified-history __unified_history
for keymap in emacs viins vicmd; do
  bindkey -M "$keymap" '^F' unified-files
  bindkey -M "$keymap" '^G' unified-grep
  bindkey -M "$keymap" '^D' unified-dirs
  bindkey -M "$keymap" '^Y' unified-yazi
  bindkey -M "$keymap" '^W' send-break
  # CSI-u: legacy Ctrl+letter and Ctrl+Shift+letter must remain distinct.
  bindkey -M "$keymap" '^[[119;5u' send-break
  bindkey -M "$keymap" '^[[87;6u' unified-exit
  bindkey -M "$keymap" '^[[119;6u' unified-exit
  bindkey -M "$keymap" '^T' undefined-key
  bindkey -M "$keymap" '^[c' undefined-key
  bindkey -M "$keymap" '^R' unified-history
done

# Request disambiguated keys only while ZLE is reading. Child programs choose
# their own protocol, and ordinary foreground commands retain TTY Ctrl-W SIGINT.
autoload -Uz add-zle-hook-widget
__unified_zle_begin() {
  [[ $TERM == dumb ]] && return 0
  # tmux negotiates modifyOtherKeys, then emits CSI-u via extended-keys-format.
  if [[ -n $TMUX ]]; then printf '\e[>4;2m'; else printf '\e[>1u'; fi
}
__unified_zle_end() {
  [[ $TERM == dumb ]] && return 0
  if [[ -n $TMUX ]]; then printf '\e[>4;0m'; else printf '\e[<u'; fi
}
add-zle-hook-widget line-init __unified_zle_begin
add-zle-hook-widget line-finish __unified_zle_end
for keymap in emacs viins vicmd; do
  bindkey -M "$keymap" '^[[102;5u' unified-files
  bindkey -M "$keymap" '^[[103;5u' unified-grep
  bindkey -M "$keymap" '^[[100;5u' unified-dirs
  bindkey -M "$keymap" '^[[121;5u' unified-yazi
  bindkey -M "$keymap" '^[[114;5u' unified-history
done

# ZLE does not decode Kitty/CSI-u itself. Reuse its existing widgets for
# functional/control keys, including packets carrying CapsLock/NumLock bits.
# Keep printable text in the terminal's normal text path.
__unified_bind_widget() {
  local map_name=$1 packet=$2 legacy=$3 fallback=$4 binding widget
  local cache_key="$1:$3"
  if (( ${+__unified_widget_cache[$cache_key]} )); then
    widget=${__unified_widget_cache[$cache_key]}
  else
    binding=$(bindkey -M "$map_name" "$legacy")
    widget=${${(z)binding}[-1]}
    __unified_widget_cache[$cache_key]=$widget
  fi
  [[ $widget == undefined-key && -n $fallback ]] && widget=$fallback
  bindkey -M "$map_name" "$packet" "$widget"
}
typeset -A __unified_widget_cache
__unified_escape() { return 0; }
zle -N unified-escape __unified_escape
__unified_keyboard_compat() {
  local map_name lock modifier base suffix legacy fallback code letter control first second
  local -a escapes
  escapes=($'\e' $'\e[27u')
  for lock in 0 64 128 192; do escapes+=($'\e[27;'$((1+lock))u); done
  for map_name in emacs viins vicmd; do
    # tmux and application-cursor mode may use these legacy Home/End aliases.
    for legacy in $'\e[1~' $'\e[7~' $'\eOH'; do
      __unified_bind_widget "$map_name" "$legacy" $'\e[H' beginning-of-line
    done
    for legacy in $'\e[4~' $'\e[8~' $'\eOF'; do
      __unified_bind_widget "$map_name" "$legacy" $'\e[F' end-of-line
    done
    for lock in 0 64 128 192; do
      modifier=$((1+lock))
      for code in 27 9 13 127 8; do
        case $code in
          27) legacy=$'\e'; fallback=unified-escape ;;
          9) legacy=$'\t'; fallback=expand-or-complete ;;
          13) legacy=$'\r'; fallback=accept-line ;;
          *) legacy=$'\x7f'; fallback=backward-delete-char ;;
        esac
        __unified_bind_widget "$map_name" $'\e['"$code;$modifier"u "$legacy" "$fallback"
      done
      # Ctrl+letters retain their existing widgets (Ctrl-W is send-break).
      for code in {1..26}; do
        printf -v control "\\$(printf '%03o' "$code")"
        for letter in $((code+96)) $((code+64)); do
          __unified_bind_widget "$map_name" $'\e['"$letter;$((5+lock))"u "$control" ''
        done
      done
      for base in 1 2 3 4 5 6 7 8; do
        modifier=$((base+lock))
        for suffix in A B C D H F P Q R S; do
          if (( base == 1 )); then
            if [[ $suffix == [PQRS] ]]; then legacy=$'\eO'"$suffix"; else legacy=$'\e['"$suffix"; fi
          else legacy=$'\e[1;'"$base$suffix"; fi
          case $suffix in
            A) fallback=up-line-or-history ;; B) fallback=down-line-or-history ;;
            C) fallback=forward-char ;; D) fallback=backward-char ;;
            H) fallback=beginning-of-line ;; F) fallback=end-of-line ;;
            *) fallback=undefined-key ;;
          esac
          if [[ $suffix == [PQRS] && $base != 1 ]]; then
            bindkey -M "$map_name" $'\e[1;'"$modifier$suffix" undefined-key
          else
            __unified_bind_widget "$map_name" $'\e[1;'"$modifier$suffix" "$legacy" "$fallback"
          fi
        done
        for code in 1 2 3 4 5 6 7 8 11 12 13 14 15 17 18 19 20 21 23 24 25 26 28 29 31 32 33 34; do
          if (( base == 1 )); then legacy=$'\e['"$code~"; else legacy=$'\e['"$code;$base~"; fi
          case $code in
            1) fallback=beginning-of-line ;; 4) fallback=end-of-line ;;
            2) fallback=overwrite-mode ;;
            3) fallback=delete-char ;; 5) fallback=up-line-or-history ;; 6) fallback=down-line-or-history ;;
            7) fallback=beginning-of-line ;; 8) fallback=end-of-line ;;
            *) fallback=undefined-key ;;
          esac
          if (( code > 8 && base != 1 )); then
            bindkey -M "$map_name" $'\e['"$code;$modifier~" undefined-key
          else
            __unified_bind_widget "$map_name" $'\e['"$code;$modifier~" "$legacy" "$fallback"
          fi
        done
      done
      for code in 8 127; do
        bindkey -M "$map_name" $'\e['"$code;$((5+lock))"u backward-kill-word
      done
      bindkey -M "$map_name" $'\e[3;'$((5+lock))'~' kill-word
      bindkey -M "$map_name" $'\e[1;'$((5+lock))D backward-word
      bindkey -M "$map_name" $'\e[1;'$((5+lock))C forward-word
      bindkey -M "$map_name" $'\e[9;'$((2+lock))u reverse-menu-complete
      bindkey -M "$map_name" $'\e[13;'$((2+lock))u accept-line
      for code in 87 119; do
        bindkey -M "$map_name" $'\e['"$code;$((6+lock))"u unified-exit
      done
    done
    # Esc is encoded as CSI 27 u under this protocol. Bind both complete
    # packets before ZLE's legacy Esc-prefix parser can consume their prefix.
    for first in "${escapes[@]}"; do
      for second in "${escapes[@]}"; do
        bindkey -M "$map_name" "$first$second" kill-whole-line
      done
    done
    __unified_bind_widget "$map_name" $'\e[27u' $'\e' unified-escape
  done
}
__unified_keyboard_compat
unfunction __unified_bind_widget __unified_keyboard_compat
unset __unified_widget_cache

# Herdr popups forward all keys to their command, including the opener.
# Only the scratch popup shell owns Alt-T; ordinary shells keep their bindings.
if [[ ${HERDR_SCRATCH_POPUP:-} == 1 ]]; then
  for keymap in emacs viins vicmd; do
    bindkey -M "$keymap" '^[t' unified-exit
    for lock in 0 64 128 192; do
      for code in 84 116; do
        bindkey -M "$keymap" $'\e['"$code;$((3+lock))"u unified-exit
      done
    done
  done
fi

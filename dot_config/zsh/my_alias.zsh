# ディレクトリ検索
function d() {
  local initial_query="${*:-}"
  local dir
  local -a fzf_opts

  fzf_opts=(
    --border-label ' Directory '
    --preview 'eza --icons=always --color=always --tree --level=2 {}'
    --preview-window 'right:60%:nowrap'
    --query "$initial_query"
  )

  dir=$(zoxide query -l | fzf "${fzf_opts[@]}")
  [ -n "$dir" ] && \cd "$dir"
}

# ファイル検索
function f() {
  local initial_query="${*:-}"
  local file
  local -a fzf_opts

  fzf_opts=(
    --header-label ' File Type '
    --border-label ' File '
    --preview 'bat --color=always {}'
    --bind 'focus:+transform-header:file --brief {} || echo "No file selected"'
    --query "$initial_query"
  )

  if command -v fd >/dev/null 2>&1; then
    file=$(fd --type f --hidden --exclude .git 2>/dev/null | \
           fzf "${fzf_opts[@]}")
  else
    file=$(rg --files --hidden --glob '!.git/*' 2>/dev/null | \
           fzf "${fzf_opts[@]}")
  fi
  [ -n "$file" ] && ${EDITOR:-nvim} "$file"
}

# 文字列一致検索
function g() {
  local initial_query="${1:-}"
  local result
  local -a fzf_opts

  fzf_opts=(
    --ansi
    --disabled
    --delimiter ':'
    --border-label ' String '
    --bind 'focus:+transform-header:echo {} | sed "s/\x1b\[[0-9;]*m//g" | cut -d: -f1 | xargs file --brief 2>/dev/null || echo "No file selected"'
    --preview 'f=$(echo {} | sed "s/\x1b\[[0-9;]*m//g" | cut -d: -f1); l=$(echo {} | sed "s/\x1b\[[0-9;]*m//g" | cut -d: -f2); [[ -n "$l" && "$l" =~ ^[0-9]+$ ]] && bat --style=numbers --color=always --highlight-line "$l" --line-range "$((l>5 ? l-5 : 1)):" "$f" 2>/dev/null || bat --style=numbers --color=always "$f" 2>/dev/null'
    --preview-window 'right:60%:nowrap'
    --query "$initial_query"
    --bind "change:reload:sleep 0.1; rg --line-number --color=always --hidden --glob '!.git/*' {q} || true"
    --bind "start:reload:rg --line-number --color=always --hidden --glob '!.git/*' {q} || true"
  )

  result=$(rg --line-number --color=always --hidden --glob '!.git/*' "${initial_query}" 2>/dev/null | \
           fzf "${fzf_opts[@]}")

  if [ -n "$result" ]; then
    local clean_result=$(echo "$result" | sed 's/\x1b\[[0-9;]*m//g')
    local file=$(echo "$clean_result" | cut -d: -f1)
    local line=$(echo "$clean_result" | cut -d: -f2)
    nvim "+${line}" "$file"
  fi
}

# yazi ファイルマネージャー
function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

# ls
alias ls="eza --icons=always"
alias ll="ls -l"
alias la="ls -a"
alias lA="ll -a"
alias lt="ls --tree --level=2"
alias lta="la --tree --level=2"
alias lT="ls --tree"
alias lTa="la --tree"
alias ld="ls -D"
alias lda="la -D"
alias lf="ls -F"
alias lfa="la -F"
alias l.="ls .*"

__ls_variant() {
  local variant="$1"
  local list_target="$2"
  case "$variant" in
    ll) ll ${list_target:+"$list_target"} ;;
    la) la ${list_target:+"$list_target"} ;;
    lA) lA ${list_target:+"$list_target"} ;;
    lt) lt ${list_target:+"$list_target"} ;;
    lta) lta ${list_target:+"$list_target"} ;;
    lT) lT ${list_target:+"$list_target"} ;;
    lTa) lTa ${list_target:+"$list_target"} ;;
    ld) ld ${list_target:+"$list_target"} ;;
    lda) lda ${list_target:+"$list_target"} ;;
    lf) lf ${list_target:+"$list_target"} ;;
    lfa) lfa ${list_target:+"$list_target"} ;;
    l.) l. ${list_target:+"$list_target"} ;;
    *)  ls ${list_target:+"$list_target"} ;;
  esac
}

__resolve_target_dir() {
  local cmd="$1"
  local target="$2"

  if [ "$cmd" = "rm" ]; then
    dirname "$target"
  elif [ -d "$target" ]; then
    printf '%s\n' "$target"
  else
    dirname "$target"
  fi
}

__run_cmd_interactive() {
  local cmd="$1"
  shift
  "$cmd" -i "$@"
}

__cmd_cd_only() {
  local cmd="$1"
  shift

  [ $# -gt 0 ] || return 1
  __run_cmd_interactive "$cmd" "$@" || return 1

  local target="${@: -1}"
  local next_dir
  next_dir="$(__resolve_target_dir "$cmd" "$target")"
  \cd "$next_dir"
}

__cmd_cd_ls() {
  local cmd="$1"
  local variant="$2"
  shift 2

  [ $# -gt 0 ] || return 1
  __run_cmd_interactive "$cmd" "$@" || return 1

  local target="${@: -1}"
  local next_dir
  next_dir="$(__resolve_target_dir "$cmd" "$target")"
  \cd "$next_dir" || return 1
  __ls_variant "$variant"
}

__cmd_ls_only() {
  local cmd="$1"
  local variant="$2"
  shift 2

  [ $# -gt 0 ] || return 1
  __run_cmd_interactive "$cmd" "$@" || return 1

  local target="${@: -1}"
  local list_target
  list_target="$(__resolve_target_dir "$cmd" "$target")"
  __ls_variant "$variant" "$list_target"
}

__cl_dispatch() {
  local variant="$1"
  local target_path="${2:-$HOME}"
  \cd "$target_path" || return 1
  __ls_variant "$variant"
}

typeset -a __LS_SUFFIXES=(s ll la lA lt lta lT lTa ld lda lf lfa l.)

for __suffix in "${__LS_SUFFIXES[@]}"; do
  if [ "$__suffix" = "s" ]; then
    __variant='base'
    __cl_name='cls'
  elif [ "$__suffix" = "l" ]; then
    __variant='l'
    __cl_name='cl'
  else
    __variant="$__suffix"
    __cl_name="c$__suffix"
  fi

  eval "$__cl_name() { __cl_dispatch $__variant \"\$1\"; }"
done

typeset -A __PMR_CMDS=( [p]='cp' [m]='mv' [r]='rm' )

for __prefix __cmd in "${(@kv)__PMR_CMDS}"; do
  eval "${__prefix}c() { __cmd_cd_only $__cmd \"\$@\"; }"

  for __suffix in "${__LS_SUFFIXES[@]}"; do
    if [ "$__suffix" = "s" ]; then
      __variant='base'
      __cdls_name="$__prefix"'cls'
      __ls_name="$__prefix"'ls'
    elif [ "$__suffix" = "l" ]; then
      __variant='l'
      __cdls_name="$__prefix"'cl'
      __ls_name="$__prefix"'l'
    else
      __variant="$__suffix"
      __cdls_name="$__prefix""c$__suffix"
      __ls_name="$__prefix""$__suffix"
    fi

    eval "$__cdls_name() { __cmd_cd_ls $__cmd $__variant \"\$@\"; }"
    eval "$__ls_name() { __cmd_ls_only $__cmd $__variant \"\$@\"; }"
  done
done

# cd
alias '/'='cd /'
alias '~'='cd ~'
alias -- '-'='cd -'
alias '-1'='cd -1'
alias '-2'='cd -2'
alias '-3'='cd -3'
alias '-4'='cd -4'
alias '-5'='cd -5'
alias '-6'='cd -6'
alias '-7'='cd -7'
alias '-8'='cd -8'
alias '-9'='cd -9'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# dir
unalias md 2>/dev/null
md() {
  [ $# -gt 0 ] || return 1
  local target="${@: -1}"
  mkdir -p -- "$@" && \cd -- "$target"
}
alias rd='rmdir'

# git
alias gcl='git clone'
alias gs='git status'
alias lg='gs'
alias gd='git diff'
alias ga='git add'
alias gA='git add -A'
alias gc='git commit'
alias gm='git commit -m'
alias gp='git push'
alias gpl='git pull --rebase'
alias gl='git log --oneline -20'
alias gb='git branch'
alias gco='git checkout'
alias gst='git stash'
alias gr='git restore'
alias gns='git restore --staged'
alias gn='git reset --soft HEAD~1'

# other
alias _=sudo
alias h='history'
alias q='exit'
alias cat='bat'
alias batcat='bat'
alias chat='codex'
alias nv='nvim'
alias latexmk='latexmk -r ~/.config/tex/.latexmkrc -pvc'

# Leading "|" command: run normally and copy stdout to clipboard
if [[ -o interactive ]]; then
  if command -v wl-copy >/dev/null 2>&1; then
    typeset -g __CLIP_CMD='wl-copy'
  elif command -v pbcopy >/dev/null 2>&1; then
    typeset -g __CLIP_CMD='pbcopy'
  elif command -v xclip >/dev/null 2>&1; then
    typeset -g __CLIP_CMD='xclip -selection clipboard'
  elif command -v xsel >/dev/null 2>&1; then
    typeset -g __CLIP_CMD='xsel --clipboard --input'
  fi

  # Ctrl+L clears the screen and shows the current directory listing.
  __clear_and_list_widget() {
    zle -I
    clear && ls
    zle redisplay
  }
  zle -N __clear_and_list_widget
  bindkey '^L' __clear_and_list_widget

  __accept_line_with_clip_prefix() {
    emulate -L zsh

    if [[ $BUFFER == \|* ]]; then
      local cmd="${BUFFER#\|}"
      cmd="${cmd#"${cmd%%[![:space:]]*}"}"

      if [[ -z $cmd ]]; then
        zle -M "コマンドを入力してください"
        return 0
      fi

      if [[ -z $__CLIP_CMD ]]; then
        zle -M "wl-copy / pbcopy / xclip / xsel が見つかりません"
        BUFFER="$cmd"
      else
        BUFFER="$cmd | tee >( ${=__CLIP_CMD} )"
      fi
    fi

    zle .accept-line
  }

  zle -N accept-line __accept_line_with_clip_prefix
fi

# --------------------------------------
# Google search from terminal
# --------------------------------------
google() {
    local search_query="$@"
    local encoded_query=$(echo "$search_query" | sed 's/ /+/g')
    xdg-open "https://www.google.com/search?q=$encoded_query"
}

# Sheldon plugin manager aliases
unalias zsh-plugin-add 2>/dev/null; function zsh-plugin-add { sheldon add --github "$1" "${1##*/}" }  # 使い方: zsh-plugin-add zsh-users/zsh-autosuggestions
alias zsh-plugin-remove='sheldon remove'             # 使い方: zsh-plugin-remove zsh-autosuggestions
alias zsh-plugin-list='bat ~/.config/sheldon/plugins.toml'
alias zsh-plugin-update='sheldon lock --update && source ~/.zshrc'
alias zsh-plugin-reload='source ~/.zshrc'

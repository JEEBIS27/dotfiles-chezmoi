[mgr]
syntect_theme = "~/.local/state/omarchy/current/theme/preview.tmTheme"
marker_copied = { fg = "{{ green }}", bg = "{{ green }}" }
marker_cut = { fg = "{{ red }}", bg = "{{ red }}" }
marker_marked = { fg = "{{ magenta }}", bg = "{{ magenta }}" }
marker_selected = { fg = "{{ orange }}", bg = "{{ orange }}" }

cwd = { fg = "{{ yellow }}" }

find_keyword = { fg = "{{ orange }}", bg = "{{ background }}" }
find_position = {}

count_copied = { fg = "{{ background }}", bg = "{{ green }}" }
count_cut = { fg = "{{ background }}", bg = "{{ red }}" }
count_selected = { fg = "{{ background }}", bg = "{{ orange }}" }

border_symbol = "│"
border_style = { fg = "{{ foreground }}" }

[indicator]
parent = { reversed = true }
current = { reversed = true }
preview = { reversed = true }

[tabs]
active = { fg = "{{ background }}", bg = "{{ accent }}" }
inactive = { fg = "{{ accent }}", bg = "{{ lighter_background }}" }

sep_inner = { open = "", close = "" }
sep_outer = { open = "", close = "" }


[mode]
normal_main = { fg = "{{ background }}", bg = "{{ accent }}" }
normal_alt = { fg = "{{ accent }}", bg = "{{ lighter_background }}" }
select_main = { fg = "{{ background }}", bg = "{{ magenta }}" }
select_alt = { fg = "{{ magenta }}", bg = "{{ lighter_background }}" }
unset_main = { fg = "{{ background }}", bg = "{{ yellow }}" }
unset_alt = { fg = "{{ yellow }}", bg = "{{ lighter_background }}" }


[status]
sep_left = { open = "", close = "" }
sep_right = { open = "", close = "" }
overall = { fg = "{{ dark_foreground }}", bg = "{{ dark_background }}" }

progress_label = { fg = "{{ accent }}", bold = true }
progress_normal = { fg = "{{ lighter_background }}", bg = "{{ background }}" }
progress_error = { fg = "{{ lighter_background }}", bg = "{{ background }}" }

perm_type = { fg = "{{ green }}" }
perm_read = { fg = "{{ yellow }}" }
perm_write = { fg = "{{ red }}" }
perm_exec = { fg = "{{ cyan }}" }
perm_sep = { fg = "{{ magenta }}" }


[pick]
border = { fg = "{{ cyan }}" }
active = { fg = "{{ magenta }}", bold = true }
inactive = {}

[input]
border = { fg = "{{ cyan }}" }
title = {}
value = {}
selected = { reversed = true }

[completion]
border = { fg = "{{ cyan }}" }
active = { reversed = true }
inactive = {}

[tasks]
border = { fg = "{{ cyan }}" }
title = {}
hovered = { fg = "{{ magenta }}" }

[which]
cols = 2
separator = " - "
separator_style = { fg = "{{ dark_foreground }}" }
mask = { bg = "{{ dark_background }}" }
rest = { fg = "{{ dark_foreground }}" }
cand = { fg = "{{ accent }}" }
desc = { fg = "{{ muted }}" }

[help]
on = { fg = "{{ cyan }}" }
run = { fg = "{{ magenta }}" }
desc = {}
hovered = { reversed = true, bold = true }
footer = { fg = "{{ background }}", bg = "{{ foreground }}" }

[notify]
title_info = { fg = "{{ green }}" }
title_warn = { fg = "{{ yellow }}" }
title_error = { fg = "{{ red }}" }

[filetype]
rules = [
    # images
    { mime = "image/*", fg = "{{ yellow }}" },

    # media
    { mime = "{audio,video}/*", fg = "{{ magenta }}" },

    # archives
    { mime = "application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}", fg = "{{ red }}" },

    # documents
    { mime = "application/{pdf,doc,rtf,vnd.*}", fg = "{{ cyan }}" },

    # broken links
    { url = "*", is = "orphan", fg = "{{ red }}" },

    # executables
    { url = "*", is = "exec", fg = "{{ green }}" },

    # fallback
    { url = "*", fg = "{{ foreground }}" },
    { url = "*/", fg = "{{ accent }}" },
]

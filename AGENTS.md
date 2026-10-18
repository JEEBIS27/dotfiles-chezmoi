# Repository maintenance

This repository manages deployed files under `/home/jeebis` through chezmoi source names. Preserve unrelated pending edits and add only explicitly changed configuration files. Never add application logs, runtime sessions, sockets, or backup files.

## Keybinding changes

Every keybinding change must update the matching table and conflict notes in `README.md`, section `キーバインド一覧`, in the same change. Check the desktop, outer terminal, Herdr, and Neovim/Yazi layers. Document which layer handles a key and any alternative for a shadowed inner binding. Validate with live bindings and a nested application test where practical.

Before changing existing documentation, read its current contents and preserve unrelated sections. `AGENTS.md` and `README.md` are repository-only documentation and are excluded from home deployment.

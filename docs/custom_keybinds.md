# Custom Keybindings for TruVium

This document lists active keybindings configured in TruVium from:

- `user-config/vimrc`
- `user-config/tmux.conf`
- `user-config/truvium/shells/zsh/tools/fzf.zsh` (plus equivalent Bash/Fish fzf integration files)

## Vim/Neovim

Leader key: `<leader>` = `,`

### Core Editing and Navigation

| Keybinding | Action |
|------------|--------|
| `<F3>` | Toggle absolute line numbers |
| `<F4>` | Toggle relative line numbers |
| `<F5>` | Redraw screen |
| `<F9>` | Toggle Tagbar |
| `<C-h>` / `<C-j>` / `<C-k>` / `<C-l>` | Move between split windows |
| `<space>` | Toggle fold under cursor |
| `<C-e>` | Toggle NERDTree |

### Clipboard, Search, and Git

| Keybinding | Action |
|------------|--------|
| `<leader>v` (insert mode) | Paste system clipboard |
| `<leader>c` (visual mode) | Yank selection to system clipboard |
| `<leader>d` (visual mode) | Delete selection to system clipboard |
| `<C-p>` | FZF file search (`:Files`) |
| `<leader>m` | FZF command/file history (`:History`) |
| `<leader>r` | Ripgrep search (`:Rg`) |
| `<leader>g` | Git-tracked files (`:GFiles`) |
| `<leader>gs` | Git status (`:vertical Git`) |
| `<leader>gc` / `<leader>gp` | Git commit / push |
| `<leader>gb` / `<leader>gl` | Git blame / log |
| `<leader>gd` / `<leader>gm` | Git diff split / vertical diff split |
| `<leader>ga` / `<leader>gr` | Git add current file / reset current file |
| `<leader>gf` | Git fetch |
| `<leader>gbr` / `<leader>gcb` / `<leader>gdb` | Checkout / create branch / delete branch |
| `<leader>go` (normal+visual) | Open current item on remote (`:GBrowse`) |

### Diagnostics, LSP, and Completion

| Keybinding | Action |
|------------|--------|
| `<leader>pe` / `<leader>ne` | Previous / next ALE diagnostic |
| `<leader>e` | Toggle ALE |
| `<leader>ye` | Copy `ALEInfo` to clipboard |
| `[g` / `]g` | Previous / next CoC diagnostic |
| `gd` / `gr` / `gi` | Definition / references / implementation |
| `K` | Hover documentation |
| `<leader>rn` | Rename symbol |
| `<leader>cd` | Show diagnostic hover |
| `<leader>cf` | Format via CoC |
| `<leader>ac` (normal+visual) | Code actions |
| `<C-space>` (insert mode) | Trigger completion |
| `<CR>` (insert mode) | Confirm completion |
| `<Tab>` / `<S-Tab>` (insert/select mode) | Completion/snippet next/previous |
| `<C-]>` (insert mode) | Dismiss Copilot suggestion |
| `<leader><Tab>` (insert mode) | Accept Copilot suggestion |

### Language and Plugin Helpers

| Keybinding | Action |
|------------|--------|
| `<leader>fv` | Format VHDL file (`FormatVHDL`) |
| `<leader>ds` | Generate Python docstring (`Pydocstring`) |
| `ga` (normal+visual) | EasyAlign |
| `<leader><leader>s` (normal+visual) | Send text/paragraph via vim-slime |
| `s` | EasyMotion 2-char jump |
| `<leader>j` / `<leader>k` | EasyMotion line down/up |

## Tmux

Prefix key: `<prefix>` = `Ctrl-a` (default `Ctrl-b` is unbound)

### Session and Pane Control

| Keybinding | Action |
|------------|--------|
| `<prefix> q` | Kill current pane |
| `<prefix> s` | Split pane horizontally (keep current path) |
| `<prefix> d` | Split pane vertically (keep current path) |
| `<prefix> r` | Reload `~/.tmux.conf` |
| `Alt-t` | Open `tmux-sessionizer` popup |
| `<prefix> m` | Toggle session persistence helper |
| `<prefix> Q` | Force tmux cleanup helper |

### Pane Navigation and Copy Mode

| Keybinding | Action |
|------------|--------|
| `Ctrl-h` / `Ctrl-j` / `Ctrl-k` / `Ctrl-l` | Smart pane navigation (Vim/fzf-aware via `tmux_keys.sh`) |
| `Ctrl-\` | Smart pane action (context-aware via `tmux_keys.sh`) |
| `Shift-Left/Right/Up/Down` | Select pane by direction |
| `<prefix> M-s` | Toggle synchronized panes |
| `y` in copy-mode-vi | Copy selection to clipboard via `xclip` |

### Plugin-Driven Keys

| Keybinding | Action |
|------------|--------|
| `<prefix> S` / `<prefix> R` | Save / restore session (resurrect) |
| `<prefix> o` / `<prefix> C-o` | Open selection / open in editor (tmux-open) |
| `<prefix> e` | Toggle sidebar tree (tmux-sidebar) |
| `Alt-f` | Launch tmux-fzf |
| `Alt-\` | Toggle floating pane (tmux-floax) |

## Terminal/Shell

FZF shell integration is enabled in Zsh/Bash/Fish and provides the standard fuzzy keybindings.

| Keybinding | Action |
|------------|--------|
| `Ctrl-r` | Fuzzy history search |
| `Ctrl-t` | Fuzzy file picker (uses `fd`, with preview) |
| `Alt-c` | Fuzzy directory jump |

Notes:

- `FZF_CTRL_T_COMMAND` and `FZF_ALT_C_COMMAND` are configured to use `fd` with hidden files (excluding `.git`).
- Zsh loads these bindings via `source <(fzf --zsh)`; Bash/Fish equivalents are also configured.

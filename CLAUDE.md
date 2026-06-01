# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal macOS dotfiles (zsh, neovim, tmux, git) installed via symlinks. Editing a tracked file in this repo immediately affects the live shell/editor/tmux config — there is no rebuild step.

## Install & maintenance commands

- `./install.sh` — full bootstrap. Symlinks every entry in its `FILES=` array from the repo into `$HOME/.<name>`, backing up any existing target to `.old`, then chains `install-tmux.sh`, `install-oh-my-zsh.sh`, `install-vim.sh`.
- `./install-oh-my-zsh.sh` — installs oh-my-zsh, then symlinks `oh_my_zsh/*.zsh` into `~/.oh-my-zsh/custom/`, `oh_my_zsh/themes/goozler.zsh-theme` into custom themes, and the zeroconfig zshrc. Also re-links the top-level `zshrc`.
- `./install-vim.sh` — creates `~/.vim/{backups,swaps,undo,autoload,bundle.d}`, links `vim/init.nvim` to `~/.config/nvim/init.vim`, installs vim-plug, and runs `nvim +PlugInstall +qall`.
- `./install-tmux.sh` — clones tpm if missing, runs `install_plugins`, sources `~/.tmux.conf`.
- `brew bundle` — install macOS deps from `Brewfile`. **Not run by `install.sh`** — must be invoked manually (see `migrate.md`).
- `./link-linter-configs.sh` / `./unlink-linter-configs.sh` — run from inside a project directory to symlink `linter-configs/*` to `$PWD/.<name>` (eslintrc, rubocop.yml, scss-lint.yml, slim-lint.yml, overcommit.yml).

## Architecture: how config files reach the system

There are three layering patterns, and changes go in different places depending on the target:

1. **Top-level dotfiles (`zshrc`, `vimrc`, `tmux.conf`, `gitconfig`, `zshenv`, `gitignore_global`, `tool-versions`, `asdfrc`, `default-*`, `rgignore`)** — listed in `install.sh`'s `FILES` array, symlinked to `~/.<name>`. Add new ones by appending to that array.
2. **oh-my-zsh custom modules (`oh_my_zsh/{docker,fzf,helpers,history,theme,tmux,vim}.zsh`)** — symlinked into `~/.oh-my-zsh/custom/` so oh-my-zsh auto-sources them. The list lives in `install-oh-my-zsh.sh`'s `FILES` array; add a module by creating the file AND appending its name.
3. **Plugin manifests** — `vim/bundle.d/plugins.vim` (vim-plug), `tmux.conf` (`@plugin` lines for tpm), and the oh-my-zsh `plugins=(...)` array in `zshrc`. Each is read by its respective plugin manager; changing them requires running the manager's install command (`:PlugInstall`, `prefix + I`, restart shell).

## Theme system (light/dark switching)

`oh_my_zsh/theme.zsh` is the source of truth. The `ITERM_PROFILE` env var (`dark`/`light`) is the single switch that drives fzf colors, `BAT_THEME`, the iTerm2 profile escape sequence, and the tmux solarized config. Two user-facing functions:
- `s` — sync to current macOS appearance (`defaults read -g AppleInterfaceStyle`).
- `i` — invert (toggle dark/light).

Both call `applyTheme`, which re-runs `_gen_fzf_default_opts`, `applyBatTheme`, sets the iTerm profile, sources the matching `tmux-colors-solarized` conf, and propagates the vars into the tmux environment via `_sync_tmux_theme_env`. When editing theme behavior, change `applyTheme` rather than its callers.

## Conflict-safe install convention

Every install script that creates a symlink first moves any existing target to `<name>.old` (`install.sh:20-23`, `install-oh-my-zsh.sh:8-9`, `install-vim.sh:11-13`). Preserve this pattern when adding new symlinks — never overwrite without backup.

## Per-machine overrides

The shell loads optional local files that are not tracked: `~/.zshenv.local` (sourced at the end of `zshenv`). Treat these as the escape hatch for machine-specific secrets/paths; don't hardcode them into tracked files.

## tmux specifics

Prefix is `C-a` (not `C-b`). Windows/panes are 1-indexed. `renumber-windows on` and `allow-rename off` are intentional. Splits use `\` (horizontal) and `-` (vertical), both preserving `pane_current_path`.

## Editor

`vim/init.nvim` makes neovim source the top-level `vimrc`, so there is one editor config for both vim and nvim. The `vimrc` is structured by `" ====` section banners — BASE SETTINGS, UI SETTINGS, COLOR SCHEME, PLUGIN SETTINGS AND MAPPINGS, CUSTOM MAPPINGS. Plugin loading is delegated to `vim/bundle.d/plugins.vim`.

## Not part of the install pipeline

`examples.sh` and `migrate.md` are personal reference snippets — they are not sourced or executed by anything. `examples.sh` is mostly Postgres dump/restore recipes run through Docker (the `-v $(pwd):/mnt` trick is what lets the dump file escape the ephemeral container back onto the host), plus a couple of kubectl/git incantations. All identifiers in it are placeholders like `<db-name>`, `<vault-username>`, `<namespace>` — fill them in at the call site. `vagrant/` and `configs/` (iStat, Little Snitch, iTerm2 plist, iterm2_profiles.json) are manual-import artifacts referenced by `migrate.md`.

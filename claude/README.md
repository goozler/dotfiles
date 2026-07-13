# Claude Code config

Utilities and settings for [Claude Code](https://claude.ai/code), linked into
`~/.claude/` by `../install-claude.sh`.

## Layout

| Path | Installed as |
|---|---|
| `hooks/*.py`, `hooks/*.sh` | symlink into `~/.claude/hooks/` |
| `scripts/*.sh` | symlink into `~/.claude/scripts/` (statusbar + helpers) |
| `keybindings.json` | symlink into `~/.claude/` |
| `settings.json` | base for the generated `~/.claude/settings.json` |
| `settings.machine.json.example` | template for per-machine overrides |

## settings.json

`install-claude.sh` builds `~/.claude/settings.json` from this `settings.json`
plus an optional `~/.claude/settings.machine.json` for per-machine values
(local paths, per-host tweaks). Permission lists and per-event hooks from the
two files are combined; other keys come from the base. This mirrors the
`~/.zshenv.local` escape hatch used elsewhere in these dotfiles — the base is
generated, so edits made in-app land in the generated file and don't touch the
tracked base.

## Install

```sh
./install-claude.sh
# optional, for per-machine values:
cp claude/settings.machine.json.example ~/.claude/settings.machine.json
$EDITOR ~/.claude/settings.machine.json
./install-claude.sh
```

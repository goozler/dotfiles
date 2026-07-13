#!/bin/bash
# Link the Claude Code utilities into ~/.claude so settings.json and tmux.conf
# (which reference them by absolute path) resolve to the copies in this repo.
#   1. hooks/ and scripts/  -> symlinked
#   2. keybindings.json      -> symlinked
#   3. settings.json         -> generated from claude/settings.json plus an
#      optional ~/.claude/settings.machine.json (per-machine overrides), since
#      Claude Code rewrites the live file in place.
# Existing real files are backed up to *.old, matching install.sh.
set -eu
cd "$(dirname "$0")"
REPO="$PWD"
DEST_ROOT="$HOME/.claude"

backup_if_real() {
  # Back up a target only if it is a real file (not one of our symlinks).
  if [ -e "$1" ] && [ ! -L "$1" ]; then
    mv -v "$1" "$1.old"
  fi
}

# 1) Symlink every file under claude/<subdir>/ into ~/.claude/<subdir>/.
for dir in claude/*/; do
  sub="$(basename "$dir")"
  dest="$DEST_ROOT/$sub"
  mkdir -p "$dest"
  for file in "$dir"*; do
    [ -f "$file" ] || continue
    name="$(basename "$file")"
    target="$dest/$name"
    backup_if_real "$target"
    ln -sfv "$REPO/$file" "$target"
  done
done

# 2) Symlink top-level static config.
for name in keybindings.json; do
  target="$DEST_ROOT/$name"
  backup_if_real "$target"
  ln -sfv "$REPO/claude/$name" "$target"
done

# 3) Generate settings.json = base config + optional per-machine overrides.
base="$REPO/claude/settings.json"
machine="$DEST_ROOT/settings.machine.json"
target="$DEST_ROOT/settings.json"
backup_if_real "$target"
[ -L "$target" ] && rm -f "$target"   # drop any legacy symlink from an older layout
if [ -f "$machine" ]; then
  # permissions.{allow,ask,deny}+additionalDirectories concatenate (how Claude
  # Code merges them across scopes); per-event hook arrays concatenate too;
  # enabledPlugins shallow-merges; empty permission arrays are dropped.
  jq -s '
    .[0] as $b | .[1] as $m |
    ($b * $m)
    | .permissions.allow = ((($b.permissions.allow // []) + ($m.permissions.allow // [])) | unique)
    | .permissions.ask = ((($b.permissions.ask // []) + ($m.permissions.ask // [])) | unique)
    | .permissions.deny = ((($b.permissions.deny // []) + ($m.permissions.deny // [])) | unique)
    | .permissions.additionalDirectories = ((($b.permissions.additionalDirectories // []) + ($m.permissions.additionalDirectories // [])) | unique)
    | .permissions |= with_entries(select((.value | type != "array") or (.value | length > 0)))
    | .enabledPlugins = (($b.enabledPlugins // {}) + ($m.enabledPlugins // {}))
    | .hooks = (
        ($b.hooks // {}) as $bh | ($m.hooks // {}) as $mh |
        reduce ((($bh | keys) + ($mh | keys)) | unique)[] as $k ({};
          .[$k] = (($bh[$k] // []) + ($mh[$k] // [])))
      )
  ' "$base" "$machine" > "$target"
  echo "generated $target (canonical + machine overrides)"
else
  cp -v "$base" "$target"
  echo "note: no $machine found — generated settings.json from the base only."
  echo "      cp claude/settings.machine.json.example $machine for per-machine overrides."
fi

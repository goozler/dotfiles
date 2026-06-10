#!/bin/bash
# Symlink Claude Code scripts into ~/.claude so settings.json and tmux.conf
# (which reference them by absolute path) resolve to the tracked copies in this
# repo. Mirrors each claude/<subdir>/ here into ~/.claude/<subdir>/ — currently
# hooks/ and scripts/. Existing real files are backed up to *.old, matching
# install.sh.
cd `dirname "$0"`

for dir in claude/*/; do
  sub=`basename "$dir"`
  dest="${HOME}/.claude/$sub"
  mkdir -p "$dest"
  for file in "$dir"*; do
    [ -e "$file" ] || continue
    name=`basename "$file"`
    target="$dest/$name"
    if [ -f "$target" ] && [ ! -L "$target" ]; then
      mv -v "$target" "$target.old"
    fi
    ln -sfv "$PWD/$file" "$target"
  done
done

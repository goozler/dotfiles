#!/bin/bash
cd `dirname "$0"`

FILES=(\
 "default-gems"\
 "default-npm-packages"\
 "default-python-packages"\
 "gitconfig"\
 "gitignore_global"\
 "rgignore"\
 "tmux.conf"\
 "vimrc"\
 "zshenv"\
 "zshrc"\
)

for file in "${FILES[@]}"; do
  if [ -f "$HOME/.$file" ]; then
    mv -v $HOME/.$file $HOME/.$file.old
  fi
  ln -sfv $PWD/$file $HOME/.$file
done

# mise global config lives at ~/.config/mise/config.toml (not a flat ~/.<name>),
# so it gets its own symlink outside the FILES loop.
mkdir -p "$HOME/.config/mise"
if [ -f "$HOME/.config/mise/config.toml" ] && [ ! -L "$HOME/.config/mise/config.toml" ]; then
  mv -v "$HOME/.config/mise/config.toml" "$HOME/.config/mise/config.toml.old"
fi
ln -sfv "$PWD/mise/config.toml" "$HOME/.config/mise/config.toml"

./install-tmux.sh
./install-oh-my-zsh.sh
./install-vim.sh
./install-claude.sh

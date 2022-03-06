#!/bin/bash
cd `dirname "$0"`

FILES=(\
 "asdfrc"\
 "default-gems"\
 "default-npm-packages"\
 "default-python-packages"\
 "gitconfig"\
 "gitignore_global"\
 "rgignore"\
 "tmux.conf"\
 "tool-versions"\
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

./install-tmux.sh
./install-oh-my-zsh.sh
./install-vim.sh

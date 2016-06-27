#!/bin/sh

cd `dirname "$0"`

FILES=(
"ackrc"
"gitconfig"
"gitignore_global"
"tmux.conf"
"vimrc"
"zshenv"
"zshrc"
)

for file in "${FILES[@]}"; do
  if [ -f "$HOME/.$file" ]; then
    mv $HOME/.$file $HOME/.$file.old
  fi

  ln -s $PWD/$file $HOME/.$file
done

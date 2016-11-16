#!/bin/bash

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
    mv -pv $HOME/.$file $HOME/.$file.old
  fi

  ln -sfv $PWD/$file $HOME/.$file
done

if [[ `uname -n` == ubuntu* ]]; then
  sudo apt-get install -y curl git silversearcher-ag tmux vim zsh
fi

git config --global user.email "goozler@gmail.com"
git config --global user.name "Alex Krutov"

tmux source-file ~/.tmux.conf

./install-vim.sh

#!/bin/bash
cd `dirname "$0"`

FILES=("gitconfig" "gitignore_global" "tmux.conf" "vimrc" "zshenv" "zshrc")
for file in "${FILES[@]}"; do
  if [ -f "$HOME/.$file" ]; then
    mv -v $HOME/.$file $HOME/.$file.old
  fi
  ln -sfv $PWD/$file $HOME/.$file
done

if [[ $(uname -n) == ubuntu* ]]; then
  sudo apt-get install -y curl git silversearcher-ag tmux zsh
fi

./install-tmux.sh
./install-oh-my-zsh.sh
./install-vim.sh

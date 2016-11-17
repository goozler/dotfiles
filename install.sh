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
  sudo apt-get install -yqq python-software-properties software-properties-common

  sudo add-apt-repository -y ppa:pi-rho/dev
  sudo apt-get update -yqq

  sudo apt-get install -y curl git silversearcher-ag zsh

  # tmux
  sudo apt-get install -yqq tmux-next=2.3~20161115~bzr3615+20-1ubuntu1~ppa0~ubuntu14.04.1
  sudo ln -s /usr/bin/tmux-next /usr/bin/tmux
fi

./install-tmux.sh
./install-vim.sh
./install-oh-my-zsh.sh

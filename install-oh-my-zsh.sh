#!/bin/bash
cd `dirname "$0"`

sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

FILES=("docker" "fzf" "helpers" "history" "tmux" "vim")
for file in "${FILES[@]}"; do
  if [ -f "$HOME/.oh-my-zsh/custom/$file.zsh" ]; then
    mv -v $HOME/.oh-my-zsh/custom/$file.zsh $HOME/.oh-my-zsh/custom/$file.zsh.old
  fi

  ln -sfv $PWD/oh_my_zsh/$file.zsh $HOME/.oh-my-zsh/custom/$file.zsh
done

mkdir -p $HOME/.oh-my-zsh/custom/themes
THEMES=("goozler")
for file in "${THEMES[@]}"; do
  if [ -f "$HOME/.oh-my-zsh/custom/themes/$file.zsh-theme" ]; then
    mv -v $HOME/.oh-my-zsh/custom/themes/$file.zsh-theme $HOME/.oh-my-zsh/custom/themes/$file.zsh-theme.old
  fi

  ln -sfv $PWD/oh_my_zsh/themes/$file.zsh-theme $HOME/.oh-my-zsh/custom/themes/$file.zsh-theme
done

mkdir -p $HOME/.oh-my-zsh/custom/zeroconfig
ln -sfv $PWD/oh_my_zsh/zeroconfig/zshrc $HOME/.oh-my-zsh/custom/zeroconfig/.zshrc

touch $HOME/.z

if [ -f "$HOME/.zshrc" ]; then
  mv -v $HOME/.zshrc $HOME/.$file.zshrc
fi
ln -sfv $PWD/zshrc $HOME/.zshrc

export ZPLUG_HOME=$HOME/.zplug
git clone https://github.com/zplug/zplug $ZPLUG_HOME
zsh -c 'source ~/.zplug/init.zsh; zplug check || zplug install'

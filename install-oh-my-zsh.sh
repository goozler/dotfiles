#!/bin/bash
cd `dirname "$0"`

sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

FILES=("fzf" "helpers" "vim")
for file in "${FILES[@]}"; do
  if [ -f "$HOME/.oh-my-zsh/custom/$file.sh" ]; then
    mv -v $HOME/.oh-my-zsh/custom/$file.sh $HOME/.oh-my-zsh/custom/$file.sh.old
  fi

  ln -sfv $PWD/oh_my_zsh/$file.sh $HOME/.oh-my-zsh/custom/$file.sh
done

THEMES=("goozler")
for file in "${THEMES[@]}"; do
  if [ -f "$HOME/.oh-my-zsh/custom/themes/$file.zsh-theme" ]; then
    mv -v $HOME/.oh-my-zsh/custom/themes/$file.zsh-theme $HOME/.oh-my-zsh/custom/themes/$file.zsh-theme.old
  fi

  ln -sfv $PWD/oh_my_zsh/themes/$file.zsh-theme $HOME/.oh-my-zsh/custom/themes/$file.zsh-theme
done

curl -sL zplug.sh/installer | zsh
zplug install

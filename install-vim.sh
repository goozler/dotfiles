#!/bin/bash
cd `dirname "$0"`

mkdir -p ~/.vim/backups
mkdir -p ~/.vim/swaps
mkdir -p ~/.vim/undo
mkdir -p ~/.vim/autoload
mkdir -p ~/.vim/bundle.d
curl --insecure -fLo ~/.vim/autoload/plug.vim https://raw.github.com/junegunn/vim-plug/master/plug.vim

FILES=("plugins")
for file in "${FILES[@]}"; do
  if [ -f "$HOME/.vim/bundle.d/$file.vim" ]; then
    mv -v $HOME/.vim/bundle.d/$file.vim $HOME/.vim/bundle.d/$file.vim.old
  fi
  ln -sfv $PWD/vim/bundle.d/$file.vim $HOME/.vim/bundle.d/$file.vim
done

YCM_CORES=1 vim -u $HOME/.vim/bundle.d/plugins.vim +PlugInstall +qall

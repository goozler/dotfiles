#!/bin/bash
cd `dirname "$0"`

mkdir -p ~/.vim/backups
mkdir -p ~/.vim/swaps
mkdir -p ~/.vim/undo
mkdir -p ~/.vim/autoload
mkdir -p ~/.vim/bundle.d
mkdir -p ~/.config/nvim

if [ -f "$HOME/.config/nvim/init.vim" ]; then
  mv -v $HOME/.config/nvim/init.vim $HOME/.config/nvim/init.vim.old
fi
ln -sfv $PWD/vim/init.nvim $HOME/.config/nvim/init.vim

curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

FILES=("plugins")
for file in "${FILES[@]}"; do
  if [ -f "$HOME/.vim/bundle.d/$file.vim" ]; then
    mv -v $HOME/.vim/bundle.d/$file.vim $HOME/.vim/bundle.d/$file.vim.old
  fi
  ln -sfv $PWD/vim/bundle.d/$file.vim $HOME/.vim/bundle.d/$file.vim
done

nvim -u $HOME/.vim/bundle.d/plugins.vim +PlugInstall +qall

#!/bin/bash
cd `dirname "$0"`

# if [[ $(uname -n) == ubuntu* ]]; then
#   sudo apt-get install -yqq checkinstall ncurses-dev python-dev python3-dev ruby-dev
#   sudo apt-get remove -yqq vim vim-runtime gvim

#   git clone https://github.com/vim/vim.git
#   cd vim
#   ./configure --with-features=huge \
#               --enable-multibyte \
#               --enable-rubyinterp=yes \
#               --enable-pythoninterp=yes \
#               --with-python-config-dir=/usr/lib/python2.7/config-x86_64-linux-gnu \
#               --enable-python3interp=yes \
#               --with-python3-config-dir=/usr/lib/python3.4/config-3.4m-x86_64-linux-gnu/ \
#               --enable-cscope --prefix=/usr
#   sudo checkinstall -y
#   sudo update-alternatives --install /usr/bin/editor editor /usr/bin/vim 1
#   sudo update-alternatives --set editor /usr/bin/vim
#   sudo update-alternatives --install /usr/bin/vi vi /usr/bin/vim 1
#   sudo update-alternatives --set vi /usr/bin/vim
# fi


mkdir -p ~/.vim/backups
mkdir -p ~/.vim/swaps
mkdir -p ~/.vim/undo
mkdir -p ~/.vim/autoload
curl --insecure -fLo ~/.vim/autoload/plug.vim https://raw.github.com/junegunn/vim-plug/master/plug.vim

vim +PlugInstall +qall

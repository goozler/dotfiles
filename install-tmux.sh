#!/bin/bash
cd `dirname "$0"`

DIR="${HOME}/.tmux/plugins/tpm"
if [ ! -d "$DIR" ]; then
   git clone 'https://github.com/tmux-plugins/tpm' $DIR
fi

$HOME/.tmux/plugins/tpm/bin/install_plugins
tmux source-file ~/.tmux.conf

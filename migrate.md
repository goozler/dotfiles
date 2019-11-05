## Pack

* `mkdir migrate`
* Projects folder
  1. Prepare db dumps
  2. `zip -v -r migrate/projects projects -x '*/node_modules/*' -x '*/deps/*' -x '*/_build/*' -x '*/build/*' -x '*/\.elixir_ls/*' -x '*/\.cache/*' -x '*/cache/*' -x '*/Pods/*' -x '*/tags' -x '*/storage/*' -x '*/dist/*' -x '*/logs/*' -x '*DS_Store'`
* ssh key

  `zip -v -r migrate/ssh .ssh/`
* directory zsh history

  `zip -v -r migrate/directory_history .directory_history/ -x '*DS_Store'`
* nvim history

  `zip migrate/nvim_history .local/share/nvim/shada/main.shada`
* iStat menus settings
* Little Snitch settings
* iTerm2 setting (General -> Preferences -> Load from Documents and choose to save a local copy)

## Unpack

* `unzip migrate/ssh.zip`
* `git clone git@github.com:goozler/dotfiles.git`
* install brew
* `brew bundle --verbose`

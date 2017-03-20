export KEYTIMEOUT=1
export AUTOENV_IN_FILE='.zsh.env'
export AUTOENV_OUT_FILE='.zsh.env.out'
export FZF_DEFAULT_COMMAND="ag --hidden \
  --ignore .git \
  --ignore node_modules \
  --ignore bower_components \
  --ignore app/assets/fonts \
  --ignore features/vcr \
  --ignore test_files \
  --ignore tmp \
  -g ''"
export FZF_CTRL_T_COMMAND="ag -g ''"
export GOPATH=$HOME
export PKG_CONFIG_PATH="/usr/local/opt/imagemagick@6/lib/pkgconfig:\
/usr/local/lib/pkgconfig"

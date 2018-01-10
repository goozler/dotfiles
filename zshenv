export KEYTIMEOUT=1
export AUTOENV_IN_FILE='.zsh.env'
export AUTOENV_OUT_FILE='.zsh.env.out'
export FZF_DEFAULT_COMMAND="rg --files --hidden"
export FZF_CTRL_T_COMMAND="rg --files"
export GOPATH=$HOME
export PKG_CONFIG_PATH="/usr/local/opt/imagemagick@6/lib/pkgconfig:\
/usr/local/lib/pkgconfig"

# Use dev docker machine as a default
export DOCKER_TLS_VERIFY="1"
export DOCKER_HOST="tcp://10.211.55.7:2376"
export DOCKER_CERT_PATH="/Users/goozler/.docker/machine/machines/eadu"
export DOCKER_MACHINE_NAME="eadu"

[[ -f ~/.zshenv.local ]] && source ~/.zshenv.local

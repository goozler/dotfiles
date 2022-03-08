export ASDF_HASHICORP_OVERWRITE_ARCH="amd64"
export DIRENV_LOG_FORMAT=""
export FZF_CTRL_T_COMMAND="rg --files"
export FZF_DEFAULT_COMMAND="rg --files --hidden"
export GOBIN=$HOME/go/bin
export GOPATH=$HOME/go
export HISTORY_FILTER_EXCLUDE=("clear")
export KERL_CONFIGURE_OPTIONS="--without-javac"
export KEYTIMEOUT=1

# Use dev docker machine as a default
# export DOCKER_TLS_VERIFY="1"
# export DOCKER_HOST="tcp://10.211.55.7:2376"
# export DOCKER_CERT_PATH="/Users/goozler/.docker/machine/machines/local"
# export DOCKER_MACHINE_NAME="local"

[[ -f ~/.zshenv.local ]] && source ~/.zshenv.local

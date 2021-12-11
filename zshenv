export KEYTIMEOUT=1
export DIRENV_LOG_FORMAT=""
export FZF_DEFAULT_COMMAND="rg --files --hidden"
export FZF_CTRL_T_COMMAND="rg --files"
export GOPATH=$HOME/go
export GOBIN=$HOME/go/bin
export HISTORY_FILTER_EXCLUDE=("clear")

# Use dev docker machine as a default
# export DOCKER_TLS_VERIFY="1"
# export DOCKER_HOST="tcp://10.211.55.7:2376"
# export DOCKER_CERT_PATH="/Users/goozler/.docker/machine/machines/local"
# export DOCKER_MACHINE_NAME="local"

[[ -f ~/.zshenv.local ]] && source ~/.zshenv.local

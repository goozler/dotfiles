# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="goozler"

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.

plugins=(
  asdf
  brew
  docker
  git
  heroku
  history
  per-directory-history
  tmux
  z
)

# User configuration
export PATH="/usr/local/bin:"\
"$GOPATH/bin:"\
"/bin:"\
"/opt/X11/bin:"\
"/sbin:"\
"/usr/bin:"\
"/usr/local/bin:"\
"/usr/local/sbin:"\
"/usr/sbin:"\
"$HOME/bin:"\
"$PATH"

# export MANPATH="/usr/local/man:$MANPATH"

source $ZSH/oh-my-zsh.sh

# You may need to manually set your language environment
export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/dsa_id"

fpath=(/usr/local/share/zsh-completions $fpath)

# FZF
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

_fzf_compgen_path() {
  rg --files "$1" | with-dir "$1"
}

_fzf_compgen_dir() {
  rg --files "$1" | only-dir "$1"
}

_gen_fzf_default_opts() {
  local base03="234"
  local base02="235"
  local base01="240"
  local base00="241"
  local base0="244"
  local base1="245"
  local base2="254"
  local base3="230"
  local yellow="136"
  local orange="166"
  local red="160"
  local magenta="125"
  local violet="61"
  local blue="33"
  local cyan="37"
  local green="64"

  # Comment and uncomment below for the light theme.

  # Solarized Dark color scheme for fzf
  # export FZF_DEFAULT_OPTS="
  #   --color fg:-1,bg:-1,hl:$blue,fg+:$base2,bg+:$base02,hl+:$blue
  #   --color info:$yellow,prompt:$yellow,pointer:$base3,marker:$base3,spinner:$yellow
  # "
  ## Solarized Light color scheme for fzf
  export FZF_DEFAULT_OPTS="
    --color fg:-1,bg:-1,hl:$blue,fg+:$base02,bg+:$base2,hl+:$blue
    --color info:$yellow,prompt:$yellow,pointer:$base03,marker:$base03,spinner:$yellow
  "
}
_gen_fzf_default_opts


# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
alias be='bundle exec'
alias gups='gsta && gup && gstp'
alias gs='gst'
alias gsta='git stash push -u'
alias glola='git log --graph --pretty='\''%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset'\'' --all --date=short'
alias rdpristine="rdd && rdc && rdm"
alias j=z
alias jj=zz
alias tach='tmux attach -t base || tmux new -s base'

alias dco=docker-compose
alias dcps='docker-compose ps'
alias dcrestart='docker-compose restart'
alias dcstop='docker-compose stop'
alias dcup='docker-compose up'
alias dcl='docker-compose logs'
alias dclf='docker-compose logs -f'
alias dcb='docker-compose build'
alias dcrs='docker-compose run --rm --service-ports'
alias dcr='docker-compose run --rm'
alias dr='docker run --rm'
alias drit='docker run --rm -it'
alias drs='docker run --rm --service-ports'
alias ds='docker stop'
alias dm=docker-machine
alias dma='docker-machine active'

alias nvim='MIX_ENV=test nvim'
if type nvim > /dev/null 2>&1; then
  alias vim='MIX_ENV=test nvim'
  alias vi='MIX_ENV=test nvim'
  alias v='MIX_ENV=test nvim'
fi

if [[ -z "$TMUX" ]]; then
  tmux attach -t base || tmux new -s base
fi

if which direnv > /dev/null; then eval "$(direnv hook zsh)"; fi

# if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi

# export NVM_DIR="$HOME/.nvm"
# source "/usr/local/opt/nvm/nvm.sh"

# test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

# source ~/.zplug/init.zsh
# zplug "Tarrasch/zsh-autoenv"
# zplug 'zplug/zplug'
# zplug 'zplug/zplug', hook-build:'zplug --self-manage'

# Install plugins if there are plugins that have not been installed
# if ! zplug check --verbose; then
#   printf "Install? [y/N]: "
#   if read -q; then
#     echo; zplug install
#   fi
# fi

# Then, source plugins and add commands to $PATH
# zplug load --verbose
# zplug load

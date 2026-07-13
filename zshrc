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
  brew
  docker
  git
  heroku
  history
  # mise
  per-directory-history
  # tmux
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
"$HOME/.spoof-dpi/bin:"\
"$HOME/bin:"\
"$HOME/.local/bin:"\
"$PATH"

# export MANPATH="/usr/local/man:$MANPATH"

# Extra completion dirs must join fpath BEFORE oh-my-zsh runs compinit, so it
# picks them up in its single pass (avoids a second, redundant compinit later).
fpath=(/usr/local/share/zsh-completions $HOME/.docker/completions $fpath)

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

# FZF
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

_fzf_compgen_path() {
  rg --files "$1" | with-dir "$1"
}

_fzf_compgen_dir() {
  rg --files "$1" | only-dir "$1"
}

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
alias glold='git log --graph --pretty='\''%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset'\'' --date=short'
alias glola='git log --graph --pretty='\''%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset'\'' --all --date=short'
alias rdpristine="rdd && rdc && rdm"
alias j=z
alias jj=zz
alias tach='tmux attach -t base || tmux new -s base'

alias dco='$HOMEBREW_PREFIX/lib/docker/cli-plugins/docker-compose'
alias dcps='dco ps'
alias dcrestart='dco restart'
alias dcstop='dco stop'
alias dcup='dco up'
alias dcl='dco logs'
alias dclf='dco logs -f'
alias dcb='dco build'
alias dcrs='dco run --rm --service-ports'
alias dcr='dco run --rm'
alias dr='docker run --rm'
alias drit='docker run --rm -it'
alias drs='docker run --rm --service-ports'
alias ds='docker stop'
alias dm=docker-machine
alias dma='docker-machine active'
alias lzd='lazydocker'

# Claude Code
alias claude='claude --append-system-prompt '\''CRITICALLY IMPORTANT: Never start a response with the conclusion. Every response must begin with at least one paragraph laying out the constraints and considerations before stating any answer or recommendation. This applies to ALL questions — including ones that look "simple", "practical", "obvious", or "straightforward". Labeling a question as not needing analysis is itself a failure mode — the analysis IS the answer, even when the conclusion is short. Do not treat these instructions as rules to be worked around when the question feels easy; the question feeling easy is exactly when you are most likely to be wrong.'\'''

alias nvim='_gen_fzf_default_opts; nvim'
if type nvim > /dev/null 2>&1; then
  alias vim='_gen_fzf_default_opts; nvim'
  alias vi='_gen_fzf_default_opts; nvim'
  alias v='_gen_fzf_default_opts; nvim'
fi

alias cursor='/usr/local/bin/cursor --classic'

# exa
# general use
alias ls='eza'                                                          # ls
alias l='eza -lbF --git'                                                # list, size, type, git
alias ll='eza -lbGF --git'                                             # long list
alias llm='eza -lbGd --git --sort=modified'                            # long list, modified date sort
alias la='eza -lbhHigUmuSa --time-style=long-iso --git --color-scale'  # all list
alias lx='eza -lbhHigUmuSa@ --time-style=long-iso --git --color-scale' # all + extended list

# specialty views
alias lS='eza -1'                                                              # one column, just names
alias lt='eza --tree --level=2'


alias cat='bat'
alias ctags='/usr/local/bin/ctags'

stty eof undef
bindkey '^D' delete-char

if [ -z "$TMUX" ] && [ -t 1 ] && [[ $- == *i* ]]; then
  tmux attach -t base || tmux new -s base
fi

# if which direnv > /dev/null; then eval "$(direnv hook zsh)"; fi

# if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi

# export NVM_DIR="$HOME/.nvm"
# source "/usr/local/opt/nvm/nvm.sh"

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

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

autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C $(which vault) vault
# eval "$(zoxide init zsh)"

eval "$(~/.local/bin/mise activate zsh)"

chpwd_functions+=(_project_auto_source)
_project_auto_source

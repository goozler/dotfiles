PROMPT='%{$fg_bold[red]%}%m%{$reset_color%}:%{$fg[green]%}%2c%{$reset_color%}%(!.#.$) '
#RPROMPT='%{$fg_bold[green]%}$(git_prompt_info)%{$reset_color%}% '

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[green]%}" # "%{$reset_color%}%{$fg[green]%}["
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[red]%}•%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN=""

ZSH_THEME_GIT_PROMPT_AHEAD="%{$fg_bold[red]%}↑"
ZSH_THEME_GIT_PROMPT_BEHIND="%{$fg_bold[red]%}↓"

git_custom_status() {
  local cb=$(current_branch)
  if [ -n "$cb" ]; then
    echo "$(parse_git_dirty)%{$fg_bold[yellow]%}$(work_in_progress)$(git_prompt_ahead)$(git_prompt_behind)%{$reset_color%}$ZSH_THEME_GIT_PROMPT_PREFIX$cb$ZSH_THEME_GIT_PROMPT_SUFFIX"
  fi
}

rbenv_version() {
  echo "%{$fg[red]%}[$(rbenv version | sed -e 's/ (set.*$//')]%{$reset_color%}"
}

elixir_version() {
  echo "%{$fg[blue]%}[$(elixir --version | awk '/Elixir/ {print $2}')]%{$reset_color%}"
}

node_version() {
  echo "%{$fg[yellow]%}[$(node --version | sed 's/^v//')]%{$reset_color%}"
}

docker_machine() {
  echo "%{$fg[blue]%}[$DOCKER_MACHINE_NAME]%{$reset_color%}"
}

# Combine it all into a final right-side prompt
string='$(git_custom_status)'

# if which rbenv &> /dev/null; then
#   string=$string' $(rbenv_version)'
# fi

# if which elixir &> /dev/null; then
#   string=$string' $(elixir_version)'
# fi

if which node &> /dev/null; then
  string=$string' $(node_version)'
fi

if [[ -n $DOCKER_MACHINE_NAME ]]; then
  string=$string' $(docker_machine)'
fi

RPS1=$string$EPS1
# RPS1='$(git_custom_status) $(rbenv_version) $(node_version)$EPS1'

#ZSH_THEME_GIT_PROMPT_PREFIX="[%{$fg[red]%}"
#ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
#ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[green]%} %{$fg[yellow]%}✗%{$fg[green]%}]%{$reset_color%}"
#ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[green]%}]"

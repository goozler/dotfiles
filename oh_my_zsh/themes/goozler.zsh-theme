PROMPT='%{$fg_bold[red]%}%m%{$reset_color%}:%{$fg[green]%}%2c%{$reset_color%}%(!.#.$) '
#RPROMPT='%{$fg_bold[green]%}$(git_prompt_info)%{$reset_color%}% '

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[green]%}" # "%{$reset_color%}%{$fg[green]%}["
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[red]%}*%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN=""

git_custom_status() {
  local cb=$(current_branch)
  if [ -n "$cb" ]; then
    echo "$(parse_git_dirty)%{$fg_bold[yellow]%}$(work_in_progress)%{$reset_color%}$ZSH_THEME_GIT_PROMPT_PREFIX$cb$ZSH_THEME_GIT_PROMPT_SUFFIX"
  fi
}

rbenv_version() {
  echo "%{$fg[red]%}[$(rbenv version | sed -e 's/ (set.*$//')]%{$reset_color%}"
}

node_version() {
    echo "%{$fg[yellow]%}[$(node --version | sed 's/^v//')]%{$reset_color%}"
}

# Combine it all into a final right-side prompt
RPS1='$(git_custom_status) $(rbenv_version) $(node_version)$EPS1'

#ZSH_THEME_GIT_PROMPT_PREFIX="[%{$fg[red]%}"
#ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
#ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[green]%} %{$fg[yellow]%}✗%{$fg[green]%}]%{$reset_color%}"
#ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[green]%}]"

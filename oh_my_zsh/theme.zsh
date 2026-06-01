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
  # Uncomment for truecolor, if your terminal supports it.
  local base03="#002b36"
  local base02="#073642"
  local base01="#586e75"
  local base00="#657b83"
  local base0="#839496"
  local base1="#93a1a1"
  local base2="#eee8d5"
  local base3="#fdf6e3"
  local yellow="#b58900"
  local orange="#cb4b16"
  local red="#dc322f"
  local magenta="#d33682"
  local violet="#6c71c4"
  local blue="#268bd2"
  local cyan="#2aa198"
  local green="#859900"
  if [[ $ITERM_PROFILE == "light" ]]; then
    ## Solarized Light color scheme for fzf
    export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS_BASE} --color fg:-1,bg:-1,hl:$blue,fg+:$base02,bg+:$base2,hl+:$blue --color info:$yellow,prompt:$yellow,pointer:$base03,marker:$base03,spinner:$yellow"
  else
    ## Solarized Dark color scheme for fzf
    export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS_BASE} --color fg:-1,bg:-1,hl:$blue,fg+:$base2,bg+:$base02,hl+:$blue --color info:$yellow,prompt:$yellow,pointer:$base3,marker:$base3,spinner:$yellow"
  fi
}

_set_iterm_profile() {
  if [[ -n "$TMUX" ]]; then
    tmux set -g allow-passthrough on
    printf "\ePtmux;\e\e]1337;SetProfile=%s\a\e\\" "$ITERM_PROFILE"
    tmux set -g allow-passthrough off
  else
    printf "\e]1337;SetProfile=%s\a" "$ITERM_PROFILE"
  fi
}

_sync_tmux_theme_env() {
  if [[ -n "$TMUX" ]]; then
    tmux set-environment -g ITERM_PROFILE "$ITERM_PROFILE"
    tmux set-environment -g FZF_DEFAULT_OPTS "$FZF_DEFAULT_OPTS"
    tmux set-environment -g BAT_THEME "$BAT_THEME"
  fi
}

_source_tmux_theme() {
  if [[ -n "$TMUX" ]]; then
    tmux source-file "$1"
  fi
}

applyTheme() {
  _gen_fzf_default_opts
  applyBatTheme

  if [[ $ITERM_PROFILE == "dark" ]]; then
    _set_iterm_profile
    _source_tmux_theme ~/.tmux/plugins/tmux-colors-solarized/tmuxcolors-dark.conf
  elif [[ $ITERM_PROFILE == "light" ]]; then
    _set_iterm_profile
    _source_tmux_theme ~/.tmux/plugins/tmux-colors-solarized/tmuxcolors-light.conf
  fi

  _sync_tmux_theme_env
}

applyBatTheme() {
  if [[ $ITERM_PROFILE == "dark" ]]; then
    export BAT_THEME="Solarized (dark)"
  elif [[ $ITERM_PROFILE == "light" ]]; then
    export BAT_THEME="Solarized (light)"
  fi
}

s() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    setItermProfile
  fi
  applyTheme
}

i() {
  if [[ $ITERM_PROFILE == "dark" ]]; then
    export ITERM_PROFILE="light"
  elif [[ $ITERM_PROFILE == "light" ]]; then
    export ITERM_PROFILE="dark"
  fi
  applyTheme
}

if [[ "$(uname -s)" == "Darwin" ]]; then
  setItermProfile() {
    val=$(defaults read -g AppleInterfaceStyle 2>/dev/null)
    if [[ $val == "Dark" ]]; then
      export ITERM_PROFILE="dark"
    else
      export ITERM_PROFILE="light"
    fi
  }

  setItermProfile
fi

_gen_fzf_default_opts
applyBatTheme

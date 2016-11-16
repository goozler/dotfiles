# https://gist.github.com/pda/5417593
vim()
{
  # Save current stty options.
  local STTYOPTS="$(stty -g)"

  # Disable intercepting of ctrl-s and ctrl-q as flow control.
  stty stop '' -ixoff -ixon

  # Execute vim.
  vim_command "$@"

  # Restore saved stty options.
  stty "$STTYOPTS"
}

vim_command()
{
  if (( $+commands[reattach-to-user-namespace] )); then
    # See: https://github.com/ChrisJohnsen/tmux-MacOSX-pasteboard
    command reattach-to-user-namespace vim "$@"
  else
    command vim "$@"
  fi
}

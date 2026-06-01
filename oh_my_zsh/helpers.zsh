viw() {
  nvim `which "$1"`
}

gitzip() {
  git archive -o $(basename $PWD).zip HEAD
}

gittgz() {
  git archive -o $(basename $PWD).tgz HEAD
}

gitdiffb() {
  if [ $# -ne 2 ]; then
    echo two branch names required
    return
  fi
  git log --graph \
  --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%Creset' \
  --abbrev-commit --date=relative $1..$2
}

make-patch() {
  local name="$(git log --oneline HEAD^.. | awk '{print $2}')"
  git format-patch HEAD^.. --stdout > "$name.patch"
}

_project_auto_source() {
  local dir=$PWD root=""

  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/Makefile" ]]; then
      root="$dir"
      break
    fi
    dir=${dir:h}
  done

  [[ -z "$root" ]] && return

  local comp="$root/Makefile.autocomplete.zsh"

  if [[ -f "$comp" && "$_MAKEFILE_COMPLETION_LOADED_FOR" != "$root" ]]; then
    source "$comp"
    _MAKEFILE_COMPLETION_LOADED_FOR="$root"
  fi
}

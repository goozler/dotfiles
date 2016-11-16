viw() {
  vim `which "$1"`
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

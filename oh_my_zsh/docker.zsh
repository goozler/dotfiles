dme() {
  eval $(docker-machine env $1)
}

dci() {
  echo 'Remove untagged images'
  docker images | grep '^<none>' | tr -s ' ' | cut -d ' ' -f 3 | xargs docker rmi
}

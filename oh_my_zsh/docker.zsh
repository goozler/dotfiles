dcrs() {
  docker-compose run --rm --service-ports $1 $2
}

dcr() {
  docker-compose run --rm $1 $2
}

dm() {
  docker-machine $1 $2
}

dme() {
  eval $(docker-machine env $1)
}

dci() {
  echo 'Remove untagged images'
  docker images | grep '^<none>' | tr -s ' ' | cut -d ' ' -f 3 | xargs docker rmi
}

#!/bin/bash

FILES=(
  "jscsrc"
  "jshintrc"
  "overcommit.yml"
  "rubocop.yml"
  "scss-lint.yml"
  "slim-lint.yml"
)

for file in "${FILES[@]}"; do
  if [ -L "$PWD/.$file" ]; then
    rm -v $PWD/.$file
  fi
done

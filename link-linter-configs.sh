#!/bin/bash

FILES=(
  "overcommit.yml"
  "rubocop.yml"
  "scss-lint.yml"
  "slim-lint.yml"
)

for file in "${FILES[@]}"; do
  if [ ! -f "$PWD/.$file" ]; then
    ln -sfv $(dirname $0)/linter-configs/$file $PWD/.$file
  fi
done

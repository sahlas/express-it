#!/bin/bash -e
echo 'remove npm-shrinkwrap.json before running tests'

#rm -f %project.root%/npm-shrinkwrap.json
cd ~/dev/mainline/topperharley

export filename="npm-shrinkwrap.json"

if [  -e "$filename" ]; then
  echo "yup its here"
  ls $filename
  exit 0
fi


#!/bin/bash -e
echo 'remove npm-shrinkwrap.json before running tests'

if [  -e "%project.root%/npm-shrinkwrap.json" ]; then
  rm -f %project.root%/npm-shrinkwrap.json
  exit 0
fi

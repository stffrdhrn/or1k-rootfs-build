#!/bin/bash
# Tool to upload artifacts to a release.  Looks
# for the last release.json file to figure out where
# to upload to.
set -ex

DIR=`dirname $0`
pushd $DIR ; DIR=$PWD ; popd
github_dir=${DIR}

# Source GITHUB_ORG GITHUB_PROJECT
. ${DIR}/../release.config
# Source github functions
. ${DIR}/github.api

for file in $@ ; do
  echo "uploading $file"
  github_upload $file
done


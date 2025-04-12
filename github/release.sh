#!/bin/bash

set -ex

## Init Globals ##
DIR=`dirname $0`
pushd $DIR ; DIR=$PWD ; popd
github_dir=${DIR}
# The location of the git repo
GIT_HOME=`dirname ${github_dir}`

# Source GITHUB_ORG GITHUB_PROJECT
. ${GIT_HOME}/release.config

# Source github functions
. ${DIR}/github.api

# Create and push git tag
git_tagnpush() {
  declare tag=$1 ; shift
  declare remote=$1 ; shift
  declare msg=$1 ; shift

  # check if the tag already exists at the destination, and return
  git -C ${GIT_HOME} ls-remote --tags --refs $remote | grep -e "/$tag$" && return 0

  # If we got this far the tag does exist at the remote so create and push it
  git -C ${GIT_HOME} tag -sf -m "$msg" $tag
  git -C ${GIT_HOME} push -f $remote $tag
}

# Get commitish used by github release api
git_getcommit() {
  declare ref=$1; shift

  git -C ${GIT_HOME} show-ref --heads --tags -s $ref
}

version=$1 ; shift
if [[ -z $version ]] ; then
  echo "usage: $0 <version>"
  exit 1
fi

# The local repo openrisc branch/tag, for generating the patch
tag="or1k-${version}"
msg="OpenRISC rootfs ${version} snapshot images"

git_tagnpush ${tag} ${GIT_REMOTE} "${msg}"
commitish=`git_getcommit ${tag}`

# Create release
github_release "${GITHUB_ORG}/${GITHUB_PROJECT}" \
  "${tag}" \
  "${msg}"

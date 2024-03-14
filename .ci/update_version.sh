#!/bin/bash

set -o errexit -o pipefail

# This script is deprecated, replaced by update_ybdb_version.sh and update_yba_version.sh
# Retained here for compatibility until packaging and release workflows switch over.

if [[ $# < 1 || $# > 2 ]]; then
  echo "Incorrect number of arguments. Usage: ${0%*/} <version> [<docker-tag>]" 1>&2
  echo "Terminating the script execution." 1>&2
  exit 1
fi

input_release_version="$1"
release_version="${input_release_version//+/.}"
docker_image_tag="$2"

if [[ -z "$docker_image_tag" ]]; then
  # Find Docker image tag respective to YugabyteDB release version
  docker_image_tag_regex=[0-9]\+.[0-9]\+.[0-9]\+.[0-9]\+-b[0-9]\+
  docker_image_tag="$(python3 ".ci/find_docker_tag.py" "-r" "${release_version}")"
  if [[ "${docker_image_tag}" =~ ${docker_image_tag_regex} ]]; then
    echo "Latest Docker image tag for '${release_version}': '${docker_image_tag}'."
  else
    echo "Failed to parse the Docker image tag: '${docker_image_tag}'" 1>&2
    exit 1
  fi
fi

.ci/update_ybdb_version.sh "${release_version}" "${docker_image_tag}"
.ci/update_yba_version.sh "${release_version}" "${docker_image_tag}"

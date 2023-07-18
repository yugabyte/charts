#!/bin/bash

set -o errexit -o pipefail

# version_gt compares the given two versions.
# It returns 0 exit code if the version1 is greater than version2.
# https://web.archive.org/web/20191003081436/http://ask.xmodulo.com/compare-two-version-numbers.html
function version_gt() {
  test "$(echo -e "$1\n$2" | sort -V | head -n 1)" != "$1"
}

function is_semver_compatible() {
  local version="$1"
  local number_of_dots
  number_of_dots=$(grep -o '\.' <<< "${version}" | wc -l)

  if [[ ${number_of_dots} -gt 2 ]]; then
    # format: 2.18.0.1
    return 1
  else
    # format: 2.18.0+1
    return 0
  fi
}


if [[ $# < 1 || $# > 2 ]]; then
  echo "Incorrect number of arguments. Usage: ${0%*/} <version> [<docker-tag>]" 1>&2
  echo "Terminating the script execution." 1>&2
  exit 1
fi

input_release_version="$1"
release_version="${input_release_version//+/.}"
docker_image_tag="$2"

# appVersion mentioned in Charts.yaml
current_version="$(grep -r "^appVersion" "stable/yugabyte/Chart.yaml" | awk '{ print $2 }')"
if ! version_gt "${release_version}" "${current_version%-b*}" ; then
  echo "Release version is either older or equal to the current version: '${release_version}' <= '${current_version%-b*}'" 1>&2
  exit 1
fi

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

# Following parameters will be updated in the below-mentioned files:
#  1. ./stable/yugabyte/Chart.yaml	 -   version, appVersion
#  2. ./stable/yugabyte/values.yaml	 -   tag
#  3. ./stable/yugaware/Chart.yaml	 -   version, appVersion
#  4. ./stable/yugaware/values.yaml	 -   tag
#  5. ./stable/yugabyte/app-readme.md	 -   *.*.*.*-b*

files_to_update_version=("stable/yugabyte/Chart.yaml" "stable/yugaware/Chart.yaml")
files_to_update_tag=("stable/yugabyte/values.yaml" "stable/yugaware/values.yaml")
chart_release_version="$(echo "${release_version}" | grep -o '[0-9]\+.[0-9]\+.[0-9]\+')"

if is_semver_compatible "${input_release_version}"; then
  chart_release_version="${input_release_version}"
fi

# Update appVersion and version in Chart.yaml
for file in "${files_to_update_version[@]}"; do
  echo "Updating file: '${file}' with version: '${chart_release_version}', appVersion: '${docker_image_tag}'"
  sed -i "s/^version: .*/version: ${chart_release_version}/g" "${file}"
  sed -i "s/^appVersion: .*/appVersion: ${docker_image_tag}/g" "${file}"
done

# Update tag in values.yaml
for file in "${files_to_update_tag[@]}"; do
  echo "Updating file: '${file}' with tag: '${docker_image_tag}'"
  sed -i "s/^  tag: .*/  tag: ${docker_image_tag}/g" "${file}"
done

# Update version number in stable/yugabyte/app-readme.md
echo "Updating file: 'stable/yugabyte/app-readme.md' with version: '${docker_image_tag}'"
sed -i "s/[0-9]\+.[0-9]\+.[0-9]\+.[0-9]\+-b[0-9]\+/${docker_image_tag}/g" "stable/yugabyte/app-readme.md"

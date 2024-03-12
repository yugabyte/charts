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


if [[ $# != 2 ]]; then
  echo "Incorrect number of arguments. Usage: ${0%*/} <version> <docker-tag>" 1>&2
  echo "Terminating the script execution." 1>&2
  exit 1
fi

release_version="$1"
docker_image_tag="$2"

# appVersion mentioned in Charts.yaml
current_version="$(grep -r "^appVersion" "stable/yugaware/Chart.yaml" | awk '{ print $2 }')"
if ! version_gt "${release_version}" "${current_version%-b*}" ; then
  echo "Release version is either older or equal to the current version: " \
    "'${release_version}' <= '${current_version%-b*}'" 1>&2
  exit 1
fi

chart_release_version="$(echo "${release_version}" | grep -o '[0-9]\+.[0-9]\+.[0-9]\+')"

if is_semver_compatible "${release_version}"; then
  chart_release_version="${release_version}"
fi

# Update appVersion and version in Chart.yaml
echo "Updating file: 'stable/yugaware/Chart.yaml' with version: " \
  "'${chart_release_version}', appVersion: '${docker_image_tag}'"
sed -i "s/^version: .*/version: ${chart_release_version}/g" "stable/yugaware/Chart.yaml"
sed -i "s/^appVersion: .*/appVersion: ${docker_image_tag}/g" "stable/yugaware/Chart.yaml"

# Update tag in values.yaml
echo "Updating file: 'stable/yugaware/values.yaml' with tag: '${docker_image_tag}'"
sed -i "s/^  tag: .*/  tag: ${docker_image_tag}/g" "stable/yugaware/values.yaml"

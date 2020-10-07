#!/bin/bash

set -o errexit -o pipefail

# version_gt compares the given two versions.
# It returns 0 exit code if the version1 is greater than version2.
# https://web.archive.org/web/20191003081436/http://ask.xmodulo.com/compare-two-version-numbers.html
function version_gt() {
  test "$(echo -e "$1\n$2" | sort -V | head -n 1)" != "$1"
}

if [[ $# -ne 1 ]]; then
  echo "No arguments supplied. Please provide the release version" 1>&2
  echo "Terminating the script execution." 1>&2
  exit 1
fi

release_version="$1"

current_stable=2.3

# We have multiple parallel release trains.
# Each train is described by its <major>.<minor> number
# We use this release train name as the parent directory for the corresponding helm charts
a=( ${release_version//./ } )
yb_release="${a[0]}.${a[1]}"

# If the yb_release is the latest (currently 2.3), use the keyword 'stable' instead
if [[ "${yb_release}" == "${current_stable}" ]]; then
  yb_release='stable'
fi

# If our yb_release dir doesn't exist, copy it from the template at .template
if [[ ! -d "${yb_release}" ]]; then
  echo "First release for ${yb_release}!"
  echo "Creating new release directory"
  cp -r .template "${yb_release}"
fi

# appVersion mentioned in Charts.yaml
current_version="$(grep -r "^appVersion" "${yb_release}/yugabyte/Chart.yaml" | awk '{ print $2 }')"
if ! version_gt "${release_version}" "${current_version%-b*}" ; then
  echo "Release version is either older or equal to the current version: '${release_version}' <= '${current_version%-b*}'" 1>&2
  exit 1
fi

# Find Docker image tag respective to YugabyteDB release version
docker_image_tag_regex=[0-9]\+.[0-9]\+.[0-9]\+.[0-9]\+-b[0-9]\+
docker_image_tag="$(python3 ".ci/find_docker_tag.py" "-r" "${release_version}")"
if [[ "${docker_image_tag}" =~ ${docker_image_tag_regex} ]]; then
  echo "Latest Docker image tag for '${release_version}': '${docker_image_tag}'."
else
  echo "Failed to parse the Docker image tag: '${docker_image_tag}'" 1>&2
  exit 1
fi

# Following parameters will be updated in the below-mentioned files:
#  1. ./${yb_release}/yugabyte/Chart.yaml	 -   version, appVersion
#  2. ./${yb_release}/yugabyte/values.yaml	 -   tag
#  3. ./${yb_release}/yugaware/Chart.yaml	 -   version, appVersion
#  4. ./${yb_release}/yugaware/values.yaml	 -   tag
#  5. ./${yb_release}/yugabyte/app-readme.md	 -   *.*.*.*-b*

files_to_update_version=("${yb_release}/yugabyte/Chart.yaml" "${yb_release}/yugaware/Chart.yaml")
files_to_update_tag=("${yb_release}/yugabyte/values.yaml" "${yb_release}/yugaware/values.yaml")
chart_release_version="$(echo "${release_version}" | grep -o '[0-9]\+.[0-9]\+.[0-9]\+')"

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

# Update version number in ${yb_release}/yugabyte/app-readme.md
echo "Updating file: '${yb_release}/yugabyte/app-readme.md' with version: '${docker_image_tag}'"
sed -i "s/[0-9]\+.[0-9]\+.[0-9]\+.[0-9]\+-b[0-9]\+/${docker_image_tag}/g" "${yb_release}/yugabyte/app-readme.md"

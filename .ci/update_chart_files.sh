#!/bin/bash
# update_chart_files.sh updates the yugabyte and yugaware chart source
# files from path_prefix to release_version. It fetches the correct
# container image tag for given release_version.
# parameter 1: release_version: newly released version in the form
# x.y.z.w.
# parameter 2: path_prefix: directory where the chart's source files
# are present.

set -o errexit -o pipefail
set -x

info() {
  echo -e "\e[34m[INFO]\e[0m $@"
}

fatal() {
  echo -e "\e[31m[FATAL]\e[0m $@" 1>&2
  exit 1
}

# version_gt compares the given two versions.
# It returns 0 exit code if the version1 is greater than version2.
# https://web.archive.org/web/20191003081436/http://ask.xmodulo.com/compare-two-version-numbers.html
function version_gt() {
  test "$(echo -e "$1\n$2" | sort -V | head -n 1)" != "$1"
}


if [[ $# -lt 2 ]]; then
  fatal "update_chart_files: need 2 arguments, got $#. Please provide the \
release version and path prefix"
fi

release_version="$1"
path_prefix="$2"

modified_files_record="$(pwd)/update_chart_files-modified"
rm -f "${modified_files_record}"

# appVersion mentioned in Charts.yaml
current_version="$(grep -r "^appVersion" "${path_prefix}/yugabyte/Chart.yaml" | awk '{ print $2 }')"
if ! version_gt "${release_version}" "${current_version%-b*}" ; then
  fatal "update_chart_files: release version is either older or equal to the \
current version: '${release_version}' <= '${current_version%-b*}'"
fi

info "update_chart_files: updating the files in '${path_prefix}' from \
'${current_version%-b*}' to '${release_version}'"

# find container image tag respective to YugabyteDB release version
container_image_tag="$(python3 ".ci/find_container_image_tag.py" "-r" "${release_version}")"
info "update_chart_files: latest container image tag for \
'${release_version}': '${container_image_tag}'"

# following parameters will be updated in the below-mentioned files:
#  1. ./${path_prefix}/yugabyte/Chart.yaml	 -   version, appVersion
#  2. ./${path_prefix}/yugabyte/values.yaml	 -   tag
#  3. ./${path_prefix}/yugaware/Chart.yaml	 -   version, appVersion
#  4. ./${path_prefix}/yugaware/values.yaml	 -   tag
#  5. ./${path_prefix}/yugabyte/app-readme.md	 -   *.*.*.*-b*

files_to_update_version=("${path_prefix}/yugabyte/Chart.yaml" "${path_prefix}/yugaware/Chart.yaml")
files_to_update_tag=("${path_prefix}/yugabyte/values.yaml" "${path_prefix}/yugaware/values.yaml")
chart_release_version="$(echo "${release_version}" | grep -o '[0-9]\+.[0-9]\+.[0-9]\+')"

# update appVersion and version in Chart.yaml
for file in "${files_to_update_version[@]}"; do
  info "update_chart_files: updating file: '${file}' with \
version: '${chart_release_version}', appVersion: '${container_image_tag}'"
  sed -i "s/^version: .*/version: ${chart_release_version}/g" "${file}"
  sed -i "s/^appVersion: .*/appVersion: ${container_image_tag}/g" "${file}"
  echo -n " ${file}" >> "${modified_files_record}"
done

# update tag in values.yaml
for file in "${files_to_update_tag[@]}"; do
  info "update_chart_files: updating file: '${file}' with tag: '${container_image_tag}'"
  sed -i "s/^  tag: .*/  tag: ${container_image_tag}/g" "${file}"
  echo -n " ${file}" >> "${modified_files_record}"
done

# update version number in ${path_prefix}/yugabyte/app-readme.md
info "update_chart_files: updating file: \
'${path_prefix}/yugabyte/app-readme.md' with version: '${container_image_tag}'"
sed -i "s/[0-9]\+.[0-9]\+.[0-9]\+.[0-9]\+-b[0-9]\+/${container_image_tag}/g" "${path_prefix}/yugabyte/app-readme.md"
echo -n " ${path_prefix}/yugabyte/app-readme.md" >> "${modified_files_record}"

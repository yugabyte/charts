#!/bin/bash

set -o errexit -o pipefail
set -x

export_modified_files() {
  echo "::set-output name=modified_files::${modified_files}"
}

trap export_modified_files EXIT

info() {
  echo -e "\e[34m[INFO]\e[0m $@"
}

fatal() {
  echo -e "\e[31m[FATAL]\e[0m $@" 1>&2
  exit 1
}


# version_lt compares the given two versions.
# It returns 0 exit code if the version1 is smaller than version2.
# https://web.archive.org/web/20191003081436/http://ask.xmodulo.com/compare-two-version-numbers.html
function version_lt() {
  test "$(echo -e "$1\n$2" | sort -rV | head -n 1)" != "$1"
}

# package_charts packages the yugabyte and yugaware charts from
# path_prefix and updates the repo index.
# argument 1: path_prefix: directory where the chart's source files
# are present.
package_charts() {
  path_prefix="$1"
  info "package_charts: packaging the charts from '${path_prefix}' \
and saving to '${repo_dir}'"
  helm package "${path_prefix}/yugabyte" --destination "${repo_dir}"
  helm package "${path_prefix}/yugaware" --destination "${repo_dir}"

  info "package_charts: updating the Helm repository index at '${repo_dir}'"
  # TODO: set the correct url
  helm repo index "${repo_dir}" --merge "${repo_dir}/index.yaml" \
       --url "https://bhavin192.github.io/yugabyte-charts/"
}

release_version="$1"
# directory used by gh-pages
repo_dir="docs"
# temporary directory to extract old chart tars.
temp_dir="chart-update"
repo_files_to_modify="${repo_dir}/index.yaml ${repo_dir}/yugabyte-${release_version%.*}.tgz ${repo_dir}/yugaware-${release_version%.*}.tgz"

# appVersion mentioned in Charts.yaml
current_version="$(grep -r "^appVersion" "stable/yugabyte/Chart.yaml" | awk '{ print $2 }')"
if ! version_lt "${release_version}" "${current_version%-b*}" ; then
  info "current version is either older or equal to the released \
version: '${current_version%-b*}' <= '${release_version}'."
  .ci/update_chart_files.sh "${release_version}" "stable"
  package_charts "stable"
  modified_files="$(cat update_chart_files-modified) ${repo_files_to_modify}"
  exit 0
fi

# check if it's an update to existing version, i.e. change in the w
# part from x.y.z.w of the version.
if [[ -f "${repo_dir}/yugabyte-${release_version%.*}.tgz" ]]; then
  last_version="${release_version%.*}"
  info "the version '${release_version%.*}' is already packaged, updating it"
else
  # find the latest version from major.minor series
  # (i.e. x.y.*). Extract the chart tars. Change the version and
  # repackage them as release_version.
  info "finding old packaged chart tar files from '${release_version%.*.*}.x' series"
  packaged_chart_files="$(find "${repo_dir}" -regex ".*/yugabyte-${release_version%.*.*}\.[0-9]+\.tgz")"
  if [[ -z "${packaged_chart_files}" ]]; then
    fatal "no old packaged chart(s) found in '${release_version%.*.*}.x' series"
  fi

  info "selecting the latest version from chart tar files: \
'$(echo ${packaged_chart_files} | tr "\n" " ")'"
  for chart in ${packaged_chart_files}; do
    # taking substring of '${repo_dir}/yugabyte-N.N.N.tgz'
    version_of_chart="${chart:14:5}"
    list_of_versions="${list_of_versions} ${version_of_chart}"
  done
  last_version="$(echo "${list_of_versions}" | tr " " "\n" | sort -V -r | head -n 1)"
  info "latest version from the ${release_version%.*.*}.x series: '${last_version}'"
fi

info "extracting the chart tars of '${last_version}' to '${temp_dir}'"
rm -rf "${temp_dir}"
mkdir "${temp_dir}"
tar -xzf "${repo_dir}/yugabyte-${last_version}.tgz" --directory "${temp_dir}"
tar -xzf "${repo_dir}/yugaware-${last_version}.tgz" --directory "${temp_dir}"
.ci/update_chart_files.sh "${release_version}" "${temp_dir}"
package_charts "${temp_dir}"
modified_files="${repo_files_to_modify}"

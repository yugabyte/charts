#!/bin/bash

set -eu -o pipefail

TEMP_DIR=""
CHART_URI=""
CHART_VERSION=""
VERIFIER_CONFIG=""
VERIFIER_OPTIONS=""
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
LOCAL_CHART=""
LOCAL_CHART_VERSION=""
CHART_VERIFIER_VERSION="1.12.2"

# YB RH Charts repository fork
REPO_OWNER="yugabyte" # add yugabyte after creating fork
REPO_NAME="openshift-helm-charts"

# RH Charts repository
REMOTE_REPO_OWNER="openshift-helm-charts"
REMOTE_REPO_NAME="charts"

BASE_BRANCH="main"

cleanup() {
  # Delete temporary directory
  if [ -n "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
    echo "Deleted temporary directory: $TEMP_DIR"
  fi
}

# Trap on script exit, calling the cleanup function
trap cleanup EXIT ERR

add_report() {
  echo "Preparing pull request..."
  git clone "https://github.com/$REPO_OWNER/$REPO_NAME.git" --branch "${BASE_BRANCH}" "${TEMP_DIR}/${REPO_NAME}"
  cd "${TEMP_DIR}/${REPO_NAME}"

  # Create a new branch
  git checkout -b "yugaware-${CHART_VERSION}"

  mkdir "charts/partners/yugabytedb/yugaware-openshift/${CHART_VERSION}"
  cp "${TEMP_DIR}/chartverifier/report.yaml" "charts/partners/yugabytedb/yugaware-openshift/${CHART_VERSION}/"

  git add .
  git commit -m "Add YugabyteDB Anywhere (yugaware) ${CHART_VERSION} chart"
  git push origin "yugaware-${CHART_VERSION}"

  cd -
}

create_pr() {
  echo "Creating pull request..."
  title="Add YugabyteDB Anywhere (yugaware) ${CHART_VERSION} chart"
  body="Adding version: ${CHART_VERSION}"
  pr_url="https://api.github.com/repos/${REMOTE_REPO_OWNER}/${REMOTE_REPO_NAME}/pulls"

  pr_data="{\"title\":\"${title}\",\"body\":\"${body}\",\"head\":\"yugaware-${CHART_VERSION}\",\"base\":\"${BASE_BRANCH}\"}"

  curl -X POST -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${pr_data}" "${pr_url}" > "${TEMP_DIR}/pr-response.yaml"

  if grep -q "state\": \"open" "${TEMP_DIR}/pr-response.yaml"; then
    echo "Created pull request successfully. $(jq -r '.url' "${TEMP_DIR}"/pr-response.yaml)"
  else
    echo "Error: Create PR API request failed: $(cat "${TEMP_DIR}"/pr-response.yaml)"
    exit 1
  fi
}

# Help function to display usage information
show_help() {
  echo "Usage: $0 [optional] [--chart_uri | --local_chart --local_chart_version]"
  echo "Mandatory"
  echo "  --chart_uri             Specify the Chart URI (e.g., https://<address>.tgz)"
  echo "  --local_chart           Specify the local chart path (Absolute path)"
  echo "  --local_chart_version   Specify the local chart version"

  echo "Optional"
  echo "  --github_token          Specify GitHub token for PR creation (works with --chart_uri)"
  echo "  --verifier_config       Specify chart verifier configuration"
  echo "  --verifier_options      Specify chart verifier options"
  exit 1
}

chart_verification() {
  cd "${TEMP_DIR}"
  params=""

  if [ -n "${VERIFIER_CONFIG}" ]; then
    params="--set ${VERIFIER_CONFIG}"
  fi

  if [ -n "${VERIFIER_OPTIONS}" ]; then
    params="${params} ${VERIFIER_OPTIONS}"
  fi

  command=$(./chart-verifier verify -w ${params} "${CHART_URI}")

  cd -

  if grep -q "outcome: FAIL" "${TEMP_DIR}/chartverifier/report.yaml"; then
    return 1
  else
    return 0
  fi
}

# Function for parse_arguments
parse_arguments() {

  while [[ "$#" -gt 0 ]]; do

    case $1 in
      --chart_uri)
        CHART_URI="${2}"

        if [[ "${CHART_URI}" =~ ^https://.*\.tgz$ ]]; then
          CHART_VERSION=$(echo "${CHART_URI}" | sed 's/.*yugaware-openshift-\(.*\)\.tgz/\1/')
        else
          echo "Error: Invalid chart URI format"
          show_help
        fi
        shift 2
        ;;
      --local_chart)
        LOCAL_CHART="$2"

        if [[ "${LOCAL_CHART}" != /* ]]; then
          echo "Error: Local chart path should be absolute."
          show_help
        fi

        if [ ! -d "${LOCAL_CHART}" ]; then
          echo "Error: Local chart path does not exist."
          show_help
        fi

        shift 2
        ;;
      --local_chart_version)
        LOCAL_CHART_VERSION="${2}"
        shift 2
        ;;
      --verifier_config)
        VERIFIER_CONFIG="${2}"
        shift 2
        ;;
      --verifier_options)
        VERIFIER_OPTIONS="${2}"
        shift 2
        ;;
      --github_token)
        GITHUB_TOKEN="${2}"
        shift 2
        ;;
      *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
  done

  if [[ -n "${CHART_URI}" && -n "${LOCAL_CHART}" ]]; then
    echo "Error: Options --chart_uri and --local_chart are mutually exclusive. Choose only one."
    show_help
  fi

  if [[ -n "${CHART_VERSION}" && -n "${LOCAL_CHART_VERSION}" ]]; then
    echo "Error: Options --chart_uri and --local_chart_version are mutually exclusive. Choose only one."
    show_help
  fi

  if [[ -n "${LOCAL_CHART}" || -n "${LOCAL_CHART_VERSION}" ]]; then
    if [[ -n "${LOCAL_CHART}" && -n "${LOCAL_CHART_VERSION}" ]]; then
      CHART_URI="${LOCAL_CHART}"
      CHART_VERSION="${LOCAL_CHART_VERSION}"
    else
      echo "Error: One of the argument --local_chart or --local_chart_version is not defined."
      show_help
    fi
  fi

  if [[ -n "${GITHUB_TOKEN}" ]]; then
    echo "Warning: A GitHub token has been found. If the verification is successful, a pull request will be created."
    if [[ -n "${LOCAL_CHART}" || -n "${LOCAL_CHART_VERSION}" ]]; then
      echo "Error: Local chart PRs are not permitted."
      exit 1
    fi
  fi

  initialize
  if chart_verification; then
    cat "${TEMP_DIR}/chartverifier/report.yaml"
    echo "Certification passed."
    if [[ -n "${GITHUB_TOKEN}" ]]; then
      # prepare PR
      add_report
      create_pr
    else
      echo "Skipping submission..."
    fi
  else
    cat "${TEMP_DIR}/chartverifier/report.yaml"
    echo "Certification failed..."
    exit 1
  fi
}

initialize() {

  for command_name in "wget" "git" "jq"; do
    if ! command -v "${command_name}" &>/dev/null; then
      echo "${command_name} not exists."
    fi
  done

  TEMP_DIR=$(mktemp -d)

  wget -O "${TEMP_DIR}/chart-verifier.tgz" \
    "https://github.com/redhat-certification/chart-verifier/releases/download/${CHART_VERIFIER_VERSION}/chart-verifier-${CHART_VERIFIER_VERSION}.tgz"
  tar -xzf "${TEMP_DIR}/chart-verifier.tgz" -C "${TEMP_DIR}"

}

# Main function
main() {
  if [ "$#" -gt 0 ]; then
    parse_arguments "$@"
  else
    show_help
  fi
}

# Call the main function in a subshell
main "$@"

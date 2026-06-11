#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

readonly ROOT_DIR="$(
  CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
)"
readonly ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"

HTTP_STATUS=
HTTP_BODY_FILE=
TEMP_FILES=()

cleanup() {
  if ((${#TEMP_FILES[@]})); then
    rm -f "${TEMP_FILES[@]}"
  fi
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '%s\n' "$*"
}

usage() {
  cat <<'EOF'
Usage: ./seed.sh [bootstrap|project|repo]

Commands:
  bootstrap  Wait for Bitbucket, create the configured project, then create
             the configured repository if BITBUCKET_REPOSITORY_NAME is set.
  project    Wait for Bitbucket and create only the configured project.
  repo       Wait for Bitbucket and create only the configured repository.
EOF
}

load_env_file() {
  if [[ -f "$ENV_FILE" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
  fi
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    die "Set ${name} in .env or the shell environment."
  fi
}

require_pattern() {
  local name="$1"
  local value="$2"
  local pattern="$3"

  if [[ -n "$value" && ! "$value" =~ $pattern ]]; then
    die "${name} contains unsupported characters."
  fi
}

request() {
  local method="$1"
  local path="$2"
  local data="${3:-}"

  HTTP_BODY_FILE="$(mktemp)"
  TEMP_FILES+=("$HTTP_BODY_FILE")

  local curl_args=(
    --silent
    --show-error
    --output "$HTTP_BODY_FILE"
    --write-out "%{http_code}"
    --user
    "${BITBUCKET_ADMIN_USERNAME}:${BITBUCKET_ADMIN_PASSWORD}"
    --request
    "$method"
  )

  if [[ -n "$data" ]]; then
    curl_args+=(
      --header
      "Content-Type: application/json"
      --data
      "$data"
    )
  fi

  HTTP_STATUS="$(
    curl "${curl_args[@]}" "${BITBUCKET_BASE_URL%/}${path}"
  )"
}

wait_for_bitbucket() {
  local base_url="${BITBUCKET_BASE_URL%/}"
  local attempt

  log "Waiting for Bitbucket at ${base_url}..."

  for ((attempt = 1; attempt <= 60; attempt += 1)); do
    if curl \
      --silent \
      --show-error \
      --output /dev/null \
      --fail \
      "${base_url}/"
    then
      return 0
    fi

    sleep 5
  done

  die "Bitbucket did not become ready in time."
}

create_project() {
  require_env BITBUCKET_PROJECT_KEY
  require_env BITBUCKET_PROJECT_NAME
  require_pattern "BITBUCKET_PROJECT_KEY" \
    "$BITBUCKET_PROJECT_KEY" \
    '^[A-Z][A-Z0-9_]{1,9}$'
  require_pattern "BITBUCKET_PROJECT_NAME" \
    "$BITBUCKET_PROJECT_NAME" \
    '^[A-Za-z0-9][A-Za-z0-9 ._-]{1,99}$'
  require_pattern "BITBUCKET_PROJECT_DESCRIPTION" \
    "${BITBUCKET_PROJECT_DESCRIPTION:-}" \
    '^[A-Za-z0-9 .,_:-]*$'

  request \
    POST \
    /rest/api/1.0/projects \
    "$(
      printf \
        '{"key":"%s","name":"%s","description":"%s","public":false}' \
        "$BITBUCKET_PROJECT_KEY" \
        "$BITBUCKET_PROJECT_NAME" \
        "${BITBUCKET_PROJECT_DESCRIPTION:-}"
    )"

  case "$HTTP_STATUS" in
    200|201)
      log "Created project ${BITBUCKET_PROJECT_KEY}."
      ;;
    409)
      log "Project ${BITBUCKET_PROJECT_KEY} already exists."
      ;;
    *)
      cat "$HTTP_BODY_FILE" >&2
      die "Project creation failed with HTTP ${HTTP_STATUS}."
      ;;
  esac
}

create_repository() {
  require_env BITBUCKET_PROJECT_KEY
  require_env BITBUCKET_REPOSITORY_NAME
  require_pattern "BITBUCKET_PROJECT_KEY" \
    "$BITBUCKET_PROJECT_KEY" \
    '^[A-Z][A-Z0-9_]{1,9}$'
  require_pattern "BITBUCKET_REPOSITORY_NAME" \
    "$BITBUCKET_REPOSITORY_NAME" \
    '^[A-Za-z0-9][A-Za-z0-9 ._-]{1,99}$'
  require_pattern "BITBUCKET_REPOSITORY_DESCRIPTION" \
    "${BITBUCKET_REPOSITORY_DESCRIPTION:-}" \
    '^[A-Za-z0-9 .,_:-]*$'

  request \
    POST \
    "/rest/api/1.0/projects/${BITBUCKET_PROJECT_KEY}/repos" \
    "$(
      printf \
        '{"name":"%s","description":"%s","scmId":"git","forkable":true}' \
        "$BITBUCKET_REPOSITORY_NAME" \
        "${BITBUCKET_REPOSITORY_DESCRIPTION:-}"
    )"

  case "$HTTP_STATUS" in
    200|201)
      log "Created repository ${BITBUCKET_REPOSITORY_NAME}."
      ;;
    409)
      log "Repository ${BITBUCKET_REPOSITORY_NAME} already exists."
      ;;
    *)
      cat "$HTTP_BODY_FILE" >&2
      die "Repository creation failed with HTTP ${HTTP_STATUS}."
      ;;
  esac
}

main() {
  local command="${1:-bootstrap}"

  trap cleanup EXIT

  case "$command" in
    help|-h|--help)
      usage
      return 0
      ;;
  esac

  load_env_file
  cd "$ROOT_DIR"

  BITBUCKET_BASE_URL="${BITBUCKET_BASE_URL:-http://127.0.0.1:${BITBUCKET_HTTP_PORT:-7990}}"
  require_env BITBUCKET_ADMIN_USERNAME
  require_env BITBUCKET_ADMIN_PASSWORD

  case "$command" in
    bootstrap)
      wait_for_bitbucket
      create_project
      if [[ -n "${BITBUCKET_REPOSITORY_NAME:-}" ]]; then
        create_repository
      else
        log "Skipping repository creation because no name was configured."
      fi
      ;;
    project)
      wait_for_bitbucket
      create_project
      ;;
    repo)
      wait_for_bitbucket
      create_repository
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"

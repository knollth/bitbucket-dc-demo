#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")

cd "$ROOT"

docker compose down --remove-orphans --volumes --rmi all

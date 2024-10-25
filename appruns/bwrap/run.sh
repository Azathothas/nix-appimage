#!/usr/bin/env bash
#LOCATION="$(dirname -- "$(readlink -f "${BASH_SOURCE}")")"
LOCATION="$(dirname "$(realpath "$0")")"
ENTRYPOINT="$(readlink -f ${LOCATION}/entrypoint)"
BWRAP_BINDS="$(printf '%s ' $(printf '%s\n' /* | grep -v -E "dev|proc" | xargs -I % echo --bind % %))"
eval "${LOCATION}/bwrap" "${BWRAP_BINDS}" --dev-bind "/dev" "/dev" --proc "/proc" --ro-bind "${LOCATION}/nix" "/nix" "${ENTRYPOINT}" "$@"

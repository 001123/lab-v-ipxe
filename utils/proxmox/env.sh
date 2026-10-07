#!/usr/bin/env bash
# Shared helpers for the Proxmox test scripts. Source this file:
#   . "$(cd "$(dirname "$0")" && pwd)/env.sh"
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CREDS="${PROJECT_ROOT}/secret/proxmox/credentials.env"

if [[ ! -f "${CREDS}" ]]; then
  echo "error: ${CREDS} not found (copy the example and fill in your Proxmox details)" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "${CREDS}"
set +a

: "${PVE_HOST:?PVE_HOST is required}"
: "${PVE_NODE:?PVE_NODE is required}"
: "${PVE_TOKEN_ID:?PVE_TOKEN_ID is required}"
: "${PVE_TOKEN_SECRET:?PVE_TOKEN_SECRET is required}"
PVE_BRIDGE="${PVE_BRIDGE:-vmbr0}"
PVE_STORAGE="${PVE_STORAGE:-local-lvm}"

command -v curl >/dev/null || { echo "error: curl is required" >&2; exit 1; }
command -v jq >/dev/null || { echo "error: jq is required" >&2; exit 1; }

CURL_INSECURE=()
if [[ "${PVE_INSECURE:-false}" == "true" ]]; then
  CURL_INSECURE=(-k)
fi

# pve_api METHOD PATH [RAW_FORM_DATA]
# RAW_FORM_DATA must already be url-encoded, e.g. "vmid=999&name=my-vm".
pve_api() {
  local method="$1" path="$2" data="${3:-}"
  if [[ -n "${data}" ]]; then
    curl -sS "${CURL_INSECURE[@]}" -X "${method}" \
      -H "Authorization: PVEAPIToken=${PVE_TOKEN_ID}=${PVE_TOKEN_SECRET}" \
      --data "${data}" \
      "${PVE_HOST}/api2/json${path}"
  else
    curl -sS "${CURL_INSECURE[@]}" -X "${method}" \
      -H "Authorization: PVEAPIToken=${PVE_TOKEN_ID}=${PVE_TOKEN_SECRET}" \
      "${PVE_HOST}/api2/json${path}"
  fi
}

# pve_api_json METHOD PATH JSON_BODY
# Use this for properties containing "," or ";", which the form-urlencoded
# parser of the PVE API mangles (e.g. net0, boot, efidisk0).
pve_api_json() {
  local method="$1" path="$2" body="$3"
  curl -sS "${CURL_INSECURE[@]}" -X "${method}" \
    -H "Authorization: PVEAPIToken=${PVE_TOKEN_ID}=${PVE_TOKEN_SECRET}" \
    -H 'Content-Type: application/json' \
    --data "${body}" \
    "${PVE_HOST}/api2/json${path}"
}

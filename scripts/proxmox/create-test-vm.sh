#!/usr/bin/env bash
# Creates (or recreates) a UEFI test VM on Proxmox used to exercise the ZTP flow
# (pending -> approve -> install -> phone-home -> sanboot -> reinstall).
#
# Usage:
#   utils/proxmox/create-test-vm.sh [--vmid 999] [--name ztp-test-999]
#       [--mac 52:54:00:99:00:01] [--memory 4096] [--cores 2] [--disk 32]
#       [--recreate] [--no-start]
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/env.sh"

VMID=999
MAC="52:54:00:99:00:01"
MEMORY=4096
CORES=2
DISK=32
RECREATE=0
START=1
NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vmid) VMID="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --mac) MAC="$2"; shift 2 ;;
    --memory) MEMORY="$2"; shift 2 ;;
    --cores) CORES="$2"; shift 2 ;;
    --disk) DISK="$2"; shift 2 ;;
    --recreate) RECREATE=1; shift ;;
    --no-start) START=0; shift ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done
NAME="${NAME:-ztp-test-${VMID}}"

status="$(pve_api GET "/nodes/${PVE_NODE}/qemu/${VMID}/status/current" | jq -r '.data.status // empty' 2>/dev/null || true)"
if [[ -n "${status}" ]]; then
  if [[ "${RECREATE}" == "1" ]]; then
    echo "==> destroying existing VM ${VMID} (status: ${status})"
    if [[ "${status}" == "running" ]]; then
      pve_api POST "/nodes/${PVE_NODE}/qemu/${VMID}/status/stop" >/dev/null
      sleep 3
    fi
    pve_api DELETE "/nodes/${PVE_NODE}/qemu/${VMID}?purge=1" >/dev/null
  else
    echo "VM ${VMID} already exists (status: ${status}); use --recreate to rebuild it"
    exit 0
  fi
fi

echo "==> creating VM ${VMID} '${NAME}': MAC ${MAC}, ${MEMORY}MB RAM, ${CORES} cores, ${DISK}GB disk"
body="$(jq -n \
  --argjson vmid "${VMID}" \
  --arg name "${NAME}" \
  --argjson memory "${MEMORY}" \
  --argjson cores "${CORES}" \
  --arg disk "${DISK}" \
  --arg mac "${MAC}" \
  --arg storage "${PVE_STORAGE}" \
  --arg bridge "${PVE_BRIDGE}" \
  '{vmid: $vmid, name: $name, memory: $memory, cores: $cores, sockets: 1, cpu: "host",
    ostype: "l26", bios: "ovmf", machine: "q35", scsihw: "virtio-scsi-single", agent: 1,
    scsi0: ($storage + ":" + $disk),
    efidisk0: ($storage + ":1,efitype=4m,pre-enrolled-keys=0"),
    net0: ("virtio,bridge=" + $bridge + ",macaddr=" + $mac),
    boot: "order=net0;scsi0"}')"

res="$(pve_api_json POST "/nodes/${PVE_NODE}/qemu" "${body}")"
if ! echo "${res}" | jq -e '.data' >/dev/null 2>&1; then
  echo "error creating VM: ${res}" >&2
  exit 1
fi
echo "==> VM ${VMID} created"

if [[ "${START}" == "1" ]]; then
  pve_api POST "/nodes/${PVE_NODE}/qemu/${VMID}/status/start" >/dev/null
  echo "==> VM ${VMID} started (boot order: net first)"
  echo "    It should now appear as 'pending' in the lab-v-ipxe UI (~10-30s)."
fi

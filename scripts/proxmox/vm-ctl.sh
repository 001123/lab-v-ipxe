#!/usr/bin/env bash
# Control Proxmox QEMU VMs (test helpers).
#
# Usage:
#   scripts/proxmox/vm-ctl.sh list
#   scripts/proxmox/vm-ctl.sh status <vmid>
#   scripts/proxmox/vm-ctl.sh start|stop|shutdown <vmid>
#   scripts/proxmox/vm-ctl.sh destroy <vmid>     (asks for confirmation)
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/env.sh"

cmd="${1:-list}"
vmid="${2:-}"

case "${cmd}" in
  list)
    pve_api GET "/nodes/${PVE_NODE}/qemu" | jq -r '.data | sort_by(.vmid)[] | "\(.vmid)\t\(.status)\t\(.name)"'
    ;;
  status)
    [[ -n "${vmid}" ]] || { echo "usage: vm-ctl.sh status <vmid>" >&2; exit 1; }
    pve_api GET "/nodes/${PVE_NODE}/qemu/${vmid}/status/current" | jq -r '.data.status'
    ;;
  start|stop|shutdown)
    [[ -n "${vmid}" ]] || { echo "usage: vm-ctl.sh ${cmd} <vmid>" >&2; exit 1; }
    pve_api POST "/nodes/${PVE_NODE}/qemu/${vmid}/status/${cmd}" >/dev/null
    echo "VM ${vmid}: ${cmd} sent"
    ;;
  destroy)
    [[ -n "${vmid}" ]] || { echo "usage: vm-ctl.sh destroy <vmid>" >&2; exit 1; }
    read -r -p "Destroy VM ${vmid} and purge its disks? [y/N] " ans
    [[ "${ans}" == "y" || "${ans}" == "Y" ]] || { echo "aborted"; exit 0; }
    pve_api DELETE "/nodes/${PVE_NODE}/qemu/${vmid}?purge=1" >/dev/null
    echo "VM ${vmid} destroyed"
    ;;
  *)
    echo "usage: vm-ctl.sh <list|status|start|stop|shutdown|destroy> [vmid]" >&2
    exit 1
    ;;
esac

#!/usr/bin/env bash
# ==============================================================================
# Deploy & Test Production lab-v-ipxe Binary on Proxmox LXC Container
#
# Fetches the latest (or specified) release from GitHub, creates an LXC container
# (ID 9200 by default) on Proxmox VE if it does not exist, deploys the binary,
# configures the systemd service, and verifies HTTP health.
#
# Usage:
#   scripts/proxmox/deploy-lxc-test.sh [OPTIONS]
#
# Options:
#   --vmid <id>           LXC Container ID (default: 9200)
#   --name <hostname>     Hostname for the container (default: lab-v-ipxe-test)
#   --tag <tag>           GitHub release tag to deploy (default: latest release)
#   --local-bin <path>    Deploy a local binary instead of downloading release
#   --template <tmpl>     Proxmox OS template (default: ubuntu-24.04-standard)
#   --ip <ip/cidr>        Static IP for the container (default: 192.168.250.12/24)
#   --gw <gateway>        Default gateway (default: 192.168.250.1)
#   --dns <nameserver>    DNS server (default: 192.168.250.1)
#   --bridge <bridge>     Proxmox network bridge (default: vmbr0)
#   --storage <storage>   Proxmox storage pool (default: local-lvm)
#   --memory <mb>         Memory in MB (default: 512)
#   --cores <cores>       CPU cores (default: 2)
#   --disk <gb>           Root disk size in GB (default: 15)
#   --port <port>         HTTP listening port (default: 80)
#   --recreate            Recreate LXC container from scratch if it exists
#   --skip-healthcheck    Skip HTTP verification after start
#   -h, --help            Show this help message
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source shared Proxmox environment and credentials
# shellcheck source=scripts/proxmox/env.sh
. "${SCRIPT_DIR}/env.sh"

# Default configuration
VMID=9200
NAME="lab-v-ipxe-test"
TAG=""
LOCAL_BIN=""
TEMPLATE=""
CONTAINER_IP="192.168.250.12/24"
GATEWAY="192.168.250.1"
NAMESERVER="192.168.250.1"
BRIDGE="${PVE_BRIDGE:-vmbr0}"
STORAGE="${PVE_STORAGE:-local-lvm}"
MEMORY=512
SWAP=512
CORES=2
DISK=15
PORT=80
RECREATE=0
SKIP_HEALTHCHECK=0

GITHUB_REPO="001123/lab-v-ipxe"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vmid) VMID="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --tag) TAG="$2"; shift 2 ;;
    --local-bin) LOCAL_BIN="$2"; shift 2 ;;
    --template) TEMPLATE="$2"; shift 2 ;;
    --ip) CONTAINER_IP="$2"; shift 2 ;;
    --gw) GATEWAY="$2"; shift 2 ;;
    --dns) NAMESERVER="$2"; shift 2 ;;
    --bridge) BRIDGE="$2"; shift 2 ;;
    --storage) STORAGE="$2"; shift 2 ;;
    --memory) MEMORY="$2"; shift 2 ;;
    --cores) CORES="$2"; shift 2 ;;
    --disk) DISK="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --recreate) RECREATE=1; shift ;;
    --skip-healthcheck) SKIP_HEALTHCHECK=1; shift ;;
    -h|--help)
      awk 'NR>=3 && NR<=28 { sub(/^#[[:space:]]?/, ""); print }' "$0"
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# Extract Proxmox host IP or hostname for SSH
PVE_SSH_HOST="$(echo "${PVE_HOST}" | sed -E 's|https?://||; s|:[0-9]+.*||')"
PVE_SSH_USER="${PVE_SSH_USER:-root}"

pve_ssh() {
  ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "${PVE_SSH_USER}@${PVE_SSH_HOST}" "$@"
}

pve_scp() {
  scp -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "$@"
}

# Ensure SSH connectivity to Proxmox
if ! pve_ssh "true" >/dev/null 2>&1; then
  echo "error: cannot connect via SSH to ${PVE_SSH_USER}@${PVE_SSH_HOST}" >&2
  echo "Please verify SSH keys or passwordless access to Proxmox VE." >&2
  exit 1
fi

echo "===================================================================="
echo "  Deploying lab-v-ipxe to Proxmox LXC ${VMID}"
echo "===================================================================="
echo "Proxmox Host : ${PVE_SSH_HOST} (Node: ${PVE_NODE})"
echo "Container ID : ${VMID} (${NAME})"
echo "Container IP : ${CONTAINER_IP} (GW: ${GATEWAY})"
echo "HTTP Port    : ${PORT}"
echo "===================================================================="

# ------------------------------------------------------------------------------
# 1. Resolve Binary (Local file or GitHub Release)
# ------------------------------------------------------------------------------
TARGET_BINARY=""
CACHE_DIR="${PROJECT_ROOT}/tmp/releases"
mkdir -p "${CACHE_DIR}"

if [[ -n "${LOCAL_BIN}" ]]; then
  if [[ ! -f "${LOCAL_BIN}" ]]; then
    echo "error: local binary not found: ${LOCAL_BIN}" >&2
    exit 1
  fi
  TARGET_BINARY="$(cd "$(dirname "${LOCAL_BIN}")" && pwd)/$(basename "${LOCAL_BIN}")"
  VERSION_LABEL="local ($(basename "${TARGET_BINARY}"))"
  echo "==> Using local binary: ${TARGET_BINARY}"
else
  # Resolve GitHub Release tag
  if [[ -z "${TAG}" ]]; then
    echo "==> Fetching latest release info from GitHub (${GITHUB_REPO})..."
    LATEST_JSON="$(curl -fsSL "https://api.github.com/repos/${GITHUB_REPO}/releases/latest")"
    TAG="$(echo "${LATEST_JSON}" | jq -r '.tag_name // empty')"
    if [[ -z "${TAG}" ]]; then
      echo "error: unable to determine latest release tag from GitHub" >&2
      exit 1
    fi
    echo "    Latest release is: ${TAG}"
  else
    echo "==> Target release tag: ${TAG}"
  fi

  VERSION_LABEL="${TAG}"
  RELEASE_DIR="${CACHE_DIR}/${TAG}"
  mkdir -p "${RELEASE_DIR}"

  ARCHIVE_NAME="lab-v-ipxe-${TAG}-linux-amd64.tar.gz"
  ARCHIVE_FILE="${RELEASE_DIR}/${ARCHIVE_NAME}"
  CHECKSUM_FILE="${RELEASE_DIR}/checksums.txt"

  # Download archive and checksum if not cached
  if [[ ! -f "${ARCHIVE_FILE}" ]]; then
    echo "==> Downloading ${ARCHIVE_NAME}..."
    ARCHIVE_URL="https://github.com/${GITHUB_REPO}/releases/download/${TAG}/${ARCHIVE_NAME}"
    curl -fL -o "${ARCHIVE_FILE}" "${ARCHIVE_URL}"
  else
    echo "==> Using cached archive: ${ARCHIVE_FILE}"
  fi

  if [[ ! -f "${CHECKSUM_FILE}" ]]; then
    echo "==> Downloading checksums.txt..."
    CHECKSUM_URL="https://github.com/${GITHUB_REPO}/releases/download/${TAG}/checksums.txt"
    curl -fsSL -o "${CHECKSUM_FILE}" "${CHECKSUM_URL}" || true
  fi

  # Verify checksum if checksums.txt exists
  if [[ -f "${CHECKSUM_FILE}" ]] && grep -q "${ARCHIVE_NAME}" "${CHECKSUM_FILE}"; then
    echo "==> Verifying SHA256 checksum..."
    EXPECTED_SHA="$(grep "${ARCHIVE_NAME}" "${CHECKSUM_FILE}" | awk '{print $1}')"
    if command -v sha256sum >/dev/null 2>&1; then
      ACTUAL_SHA="$(sha256sum "${ARCHIVE_FILE}" | awk '{print $1}')"
    else
      ACTUAL_SHA="$(shasum -a 256 "${ARCHIVE_FILE}" | awk '{print $1}')"
    fi
    if [[ "${EXPECTED_SHA}" != "${ACTUAL_SHA}" ]]; then
      echo "error: SHA256 mismatch!" >&2
      echo "  Expected: ${EXPECTED_SHA}" >&2
      echo "  Actual:   ${ACTUAL_SHA}" >&2
      exit 1
    fi
    echo "    Checksum OK: ${ACTUAL_SHA}"
  fi

  # Extract binary
  EXTRACT_DIR="${RELEASE_DIR}/extracted"
  mkdir -p "${EXTRACT_DIR}"
  tar -xzf "${ARCHIVE_FILE}" -C "${EXTRACT_DIR}"
  BIN_FOUND="$(find "${EXTRACT_DIR}" -type f -name "lab-v-ipxe" | head -n 1)"
  if [[ -z "${BIN_FOUND}" || ! -f "${BIN_FOUND}" ]]; then
    echo "error: lab-v-ipxe binary not found in archive" >&2
    exit 1
  fi
  TARGET_BINARY="${BIN_FOUND}"
fi

# ------------------------------------------------------------------------------
# 2. Check / Create Proxmox LXC Container
# ------------------------------------------------------------------------------
CONTAINER_EXISTS=0
if pve_ssh "pct status ${VMID} >/dev/null 2>&1"; then
  CONTAINER_EXISTS=1
fi

if [[ "${CONTAINER_EXISTS}" -eq 1 ]]; then
  if [[ "${RECREATE}" -eq 1 ]]; then
    echo "==> Destroying existing LXC container ${VMID} (--recreate specified)..."
    CURRENT_STATUS="$(pve_ssh "pct status ${VMID}" | awk '{print $2}')"
    if [[ "${CURRENT_STATUS}" == "running" ]]; then
      pve_ssh "pct stop ${VMID}"
      sleep 2
    fi
    pve_ssh "pct destroy ${VMID} --purge 1"
    CONTAINER_EXISTS=0
  else
    echo "==> LXC container ${VMID} already exists. Proceeding with in-place update..."
  fi
fi

if [[ "${CONTAINER_EXISTS}" -eq 0 ]]; then
  # Determine OS template (prefer Ubuntu 24.04 because GitHub CI compiles on Ubuntu 24.04 with glibc 2.39)
  CHOSEN_TMPL="${TEMPLATE}"
  if [[ -z "${CHOSEN_TMPL}" ]]; then
    # Look for ubuntu-24.04 in local storage first
    CHOSEN_TMPL="$(pve_ssh "pveam list local | grep -E 'ubuntu-24\.04' | head -n 1" | awk '{print $1}')"
    if [[ -z "${CHOSEN_TMPL}" ]]; then
      # Check if available in pveam catalog
      LATEST_AVAIL="$(pve_ssh "pveam available | grep -E 'ubuntu-24\.04-standard' | head -n 1" | awk '{print $2}')"
      if [[ -n "${LATEST_AVAIL}" ]]; then
        echo "==> Downloading Ubuntu 24.04 template (${LATEST_AVAIL}) to local storage..."
        pve_ssh "pveam download local ${LATEST_AVAIL}"
        CHOSEN_TMPL="local:vztmpl/${LATEST_AVAIL}"
      else
        # Fallback to debian-12
        CHOSEN_TMPL="$(pve_ssh "pveam list local | grep debian-12-standard | head -n 1" | awk '{print $1}')"
      fi
    fi
  fi

  if [[ -z "${CHOSEN_TMPL}" ]]; then
    echo "error: no suitable OS template found on Proxmox" >&2
    exit 1
  fi
  echo "==> Using container template: ${CHOSEN_TMPL}"

  OSTYPE="ubuntu"
  if [[ "${CHOSEN_TMPL}" =~ debian ]]; then
    OSTYPE="debian"
  fi

  echo "==> Creating LXC container ${VMID} (${NAME})..."
  pve_ssh "pct create ${VMID} \"${CHOSEN_TMPL}\" \
    --hostname \"${NAME}\" \
    --cores \"${CORES}\" \
    --memory \"${MEMORY}\" \
    --swap \"${SWAP}\" \
    --features \"nesting=1\" \
    --unprivileged 1 \
    --net0 \"name=eth0,bridge=${BRIDGE},firewall=0,ip=${CONTAINER_IP},gw=${GATEWAY},type=veth\" \
    --nameserver \"${NAMESERVER}\" \
    --rootfs \"${STORAGE}:${DISK}\" \
    --ostype \"${OSTYPE}\" \
    --onboot 1 \
    --start 0"

  echo "==> Starting LXC container ${VMID}..."
  pve_ssh "pct start ${VMID}"

  echo "==> Waiting for network and DNS inside LXC ${VMID}..."
  i=0
  while [ "$i" -lt 30 ]; do
    if pve_ssh "pct exec ${VMID} -- ping -c 1 -W 1 ${GATEWAY} >/dev/null 2>&1"; then
      break
    fi
    sleep 1
    i=$((i + 1))
  done

  echo "==> Installing runtime dependencies (libsqlite3-0, ca-certificates, curl, xorriso, p7zip-full, libarchive-tools)..."
  pve_ssh "pct exec ${VMID} -- bash -c 'DEBIAN_FRONTEND=noninteractive apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq libsqlite3-0 ca-certificates curl xorriso p7zip-full libarchive-tools'"
else
  # Ensure existing container is running
  CURRENT_STATUS="$(pve_ssh "pct status ${VMID}" | awk '{print $2}')"
  if [[ "${CURRENT_STATUS}" != "running" ]]; then
    echo "==> Starting stopped LXC container ${VMID}..."
    pve_ssh "pct start ${VMID}"
    sleep 3
  fi

  # Check if libsqlite3 or xorriso is installed
  if ! pve_ssh "pct exec ${VMID} -- dpkg -s libsqlite3-0 xorriso >/dev/null 2>&1"; then
    echo "==> Installing missing runtime dependencies (libsqlite3-0, xorriso, p7zip-full, libarchive-tools)..."
    pve_ssh "pct exec ${VMID} -- bash -c 'DEBIAN_FRONTEND=noninteractive apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq libsqlite3-0 ca-certificates curl xorriso p7zip-full libarchive-tools'"
  fi
fi

# ------------------------------------------------------------------------------
# 3. Deploy Binary to Container
# ------------------------------------------------------------------------------
HOST_STAGING="/tmp/lab-v-ipxe-deploy-${VMID}"
REMOTE_OPT="/opt/lab-v-ipxe"
REMOTE_BIN="${REMOTE_OPT}/lab-v-ipxe"

echo "==> Transferring binary to Proxmox host staging..."
pve_scp "${TARGET_BINARY}" "${PVE_SSH_USER}@${PVE_SSH_HOST}:${HOST_STAGING}"

echo "==> Preparing container directory ${REMOTE_OPT}..."
pve_ssh "pct exec ${VMID} -- mkdir -p ${REMOTE_OPT} ${REMOTE_OPT}/data"

# Stop existing service if running before replacing binary
if pve_ssh "pct exec ${VMID} -- systemctl is-active lab-v-ipxe >/dev/null 2>&1"; then
  echo "==> Stopping running lab-v-ipxe service..."
  pve_ssh "pct exec ${VMID} -- systemctl stop lab-v-ipxe"
fi

# Terminate any stray processes and remove existing binary so pct push does not encounter 'Text file busy'
pve_ssh "pct exec ${VMID} -- bash -c 'killall -9 lab-v-ipxe 2>/dev/null || true; [ -f ${REMOTE_BIN} ] && cp -f ${REMOTE_BIN} ${REMOTE_BIN}.bak 2>/dev/null || true; rm -f ${REMOTE_BIN}'"

echo "==> Pushing binary into LXC ${VMID}..."
pve_ssh "pct push ${VMID} ${HOST_STAGING} ${REMOTE_BIN} --perms 755"
pve_ssh "pct exec ${VMID} -- chmod +x ${REMOTE_BIN}"
pve_ssh "rm -f ${HOST_STAGING}"

# ------------------------------------------------------------------------------
# 4. Configure & Start Systemd Service
# ------------------------------------------------------------------------------
PLAIN_IP="${CONTAINER_IP%%/*}"
BASE_URL="http://${PLAIN_IP}"
if [[ "${PORT}" != "80" ]]; then
  BASE_URL="http://${PLAIN_IP}:${PORT}"
fi

echo "==> Configuring systemd service /etc/systemd/system/lab-v-ipxe.service..."
SERVICE_UNIT="[Unit]
Description=Lab V iPXE Provisioning Server (Test Environment)
After=network.target

[Service]
Type=simple
WorkingDirectory=${REMOTE_OPT}
ExecStart=${REMOTE_BIN}
Restart=always
RestartSec=3
Environment=LAB_V_IPXE_PORT=${PORT}
Environment=LAB_V_IPXE_BASE_URL=${BASE_URL}
Environment=LAB_V_IPXE_DATA_DIR=${REMOTE_OPT}/data
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
"

pve_ssh "pct exec ${VMID} -- bash -c 'cat <<\"EOF\" > /etc/systemd/system/lab-v-ipxe.service
${SERVICE_UNIT}
EOF'"

echo "==> Reloading systemd and enabling service..."
pve_ssh "pct exec ${VMID} -- systemctl daemon-reload"
pve_ssh "pct exec ${VMID} -- systemctl enable lab-v-ipxe"
pve_ssh "pct exec ${VMID} -- systemctl restart lab-v-ipxe"

# ------------------------------------------------------------------------------
# 5. Verification & Health Check
# ------------------------------------------------------------------------------
echo "==> Verifying service status..."
sleep 2

if ! pve_ssh "pct exec ${VMID} -- systemctl is-active lab-v-ipxe >/dev/null 2>&1"; then
  echo "!! Service failed to start! Displaying recent journal logs:" >&2
  pve_ssh "pct exec ${VMID} -- journalctl -u lab-v-ipxe -n 25 --no-pager" >&2
  exit 1
fi

if [[ "${SKIP_HEALTHCHECK}" -eq 0 ]]; then
  echo "==> Polling HTTP endpoint at ${BASE_URL}/healthz ..."
  HEALTH_OK=0
  HEALTH_BODY=""
  for attempt in {1..15}; do
    HEALTH_RESP="$(curl -sS -m 3 "${BASE_URL}/healthz" 2>/dev/null || true)"
    if echo "${HEALTH_RESP}" | grep -q '"status":"ok"'; then
      HEALTH_OK=1
      HEALTH_BODY="${HEALTH_RESP}"
      break
    fi
    sleep 1
  done

  if [[ "${HEALTH_OK}" -eq 1 ]]; then
    echo "    Health check PASSED: ${HEALTH_BODY}"
  else
    echo "!! Health check warning: ${BASE_URL}/healthz did not return ok within 15s"
    echo "    Checking service logs:"
    pve_ssh "pct exec ${VMID} -- journalctl -u lab-v-ipxe -n 20 --no-pager" || true
  fi
fi

echo
echo "===================================================================="
echo "  lab-v-ipxe Deployment Complete!"
echo "===================================================================="
echo "Version / Tag : ${VERSION_LABEL}"
echo "Container ID  : ${VMID}"
echo "Service State : active (running)"
echo "Web Dashboard : ${BASE_URL}"
echo "Credentials   : admin@ipxe.local / admin@pwd"
echo "API / Health  : ${BASE_URL}/healthz"
echo "iPXE Endpoint : ${BASE_URL}/boot.ipxe"
echo
echo "Quick Commands:"
echo "  View logs   : ssh ${PVE_SSH_USER}@${PVE_SSH_HOST} \"pct exec ${VMID} -- journalctl -u lab-v-ipxe -f\""
echo "  Restart     : ssh ${PVE_SSH_USER}@${PVE_SSH_HOST} \"pct exec ${VMID} -- systemctl restart lab-v-ipxe\""
echo "  Console     : ssh ${PVE_SSH_USER}@${PVE_SSH_HOST} \"pct enter ${VMID}\""
echo "===================================================================="

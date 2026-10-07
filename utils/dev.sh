#!/usr/bin/env bash
# Runs the dev server: SQLite and assets live in ./tmp.
# For live frontend reload run `cd web && npm run dev` in another terminal
# (Vite proxies API calls to this server).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

export LAB_V_IPXE_DATA_DIR="${LAB_V_IPXE_DATA_DIR:-${ROOT}/tmp}"
echo "==> data dir: ${LAB_V_IPXE_DATA_DIR}"
echo "==> UI dev:   cd web && npm run dev  (http://localhost:5173, proxies /api -> :8080)"
exec v -g run .

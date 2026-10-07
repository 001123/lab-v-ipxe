#!/usr/bin/env bash
# Runs the dev server: SQLite and assets live in ./tmp; the dev binary (and its
# macOS .dSYM debug bundle) are built into ./tmp as well, keeping the repo root
# clean. For live frontend reload run `cd web && npm run dev` in another
# terminal (Next dev proxies API calls to this server).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

export LAB_V_IPXE_DATA_DIR="${LAB_V_IPXE_DATA_DIR:-${ROOT}/tmp}"
mkdir -p "${LAB_V_IPXE_DATA_DIR}"
echo "==> data dir: ${LAB_V_IPXE_DATA_DIR}"
echo "==> UI dev:   cd web && npm run dev  (http://localhost:3000, proxies /api -> :8080)"
if [[ ! -f web/out/index.html ]]; then
  echo "warning: web/out is missing; the embedded UI stays disabled."
  echo "         run: (cd web && npm run build) && v run utils/gen_embed.vsh"
fi
exec v -g -o "${ROOT}/tmp/lab-v-ipxe-dev" run .

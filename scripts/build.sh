#!/usr/bin/env bash
# Builds the frontend, regenerates the embedded asset file and produces release
# binaries into bin/.
#
# Usage:
#   scripts/build.sh                 # frontend + darwin-arm64 + linux-amd64
#   scripts/build.sh --skip-frontend # reuse the current web/out
#   scripts/build.sh --host-only     # only the host binary
#   scripts/build.sh --linux-only    # only the linux-amd64 cross binary
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

SKIP_FE=0
HOST_ONLY=0
LINUX_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --skip-frontend) SKIP_FE=1 ;;
    --host-only) HOST_ONLY=1 ;;
    --linux-only) LINUX_ONLY=1 ;;
    *) echo "unknown option: ${arg}" >&2; exit 1 ;;
  esac
done

echo "==> preflight"
v version | head -1
V_BIN="$(command -v v)"
# resolve symlinks (e.g. mise/brew shims); macOS readlink has no -f
while [ -L "$V_BIN" ]; do
  target="$(readlink "$V_BIN")"
  case "$target" in
    /*) V_BIN="$target" ;;
    *) V_BIN="$(dirname "$V_BIN")/$target" ;;
  esac
done
VBIN_DIR="$(cd "$(dirname "$V_BIN")" && pwd -P)"
if [[ -d "${VBIN_DIR}/thirdparty" ]]; then
  VROOT="${VBIN_DIR}"
elif [[ -d "${VBIN_DIR}/../thirdparty" ]]; then
  VROOT="$(cd "${VBIN_DIR}/.." && pwd -P)"
else
  VROOT=""
fi
if [[ -n "${VROOT}" && ! -f "${VROOT}/thirdparty/sqlite/sqlite3.c" ]]; then
  echo "note: ${VROOT}/thirdparty/sqlite is missing (needed for linux builds). Run once:"
  echo "      v run ${VROOT}/vlib/db/sqlite/install_thirdparty_sqlite.vsh"
fi

if [[ "${SKIP_FE}" == "0" ]]; then
  echo "==> building frontend"
  (cd web && npm install --no-fund --no-audit && npm run build)
  v run scripts/gen_embed.vsh
fi

echo "==> type-check"
v -check .

echo "==> format check"
v fmt -verify .

mkdir -p bin
if [[ "${LINUX_ONLY}" == "0" ]]; then
  echo "==> building bin/lab-v-ipxe-darwin-arm64"
  v -prod -o bin/lab-v-ipxe-darwin-arm64 .
fi
if [[ "${HOST_ONLY}" == "0" ]]; then
  echo "==> building bin/lab-v-ipxe-linux-amd64 (cross; first run downloads the linuxroot sysroot)"
  # Cross-build quirks (macOS host):
  #  - PKG_CONFIG_LIBDIR: skip host pkg-config so the bundled thirdparty sqlite3.c
  #    is used instead of macOS headers.
  #  - the macos->linux driver does not compile thirdparty .c inputs, so compile
  #    sqlite3.c for the target once and pass the object via -cflags.
  #  - the sysroot's libssl.so references symbols newer than its bundled glibc
  #    (2.31); allow shlib undefined refs (resolved at runtime by the distro).
  #  - -parallel-cc: skip -flto, because lld cannot read newer-clang bitcode.
  CROSS_SQLITE_OBJ="${ROOT}/tmp/sqlite3-linux-amd64.o"
  if [[ ! -f "${CROSS_SQLITE_OBJ}" ]]; then
    if [[ -z "${VROOT}" || ! -f "${VROOT}/thirdparty/sqlite/sqlite3.c" ]]; then
      echo "error: ${VROOT:-VROOT}/thirdparty/sqlite/sqlite3.c not found; run the install command printed above" >&2
      exit 1
    fi
    echo "==> compiling bundled sqlite3.c for linux-amd64 (one time)"
    mkdir -p "$(dirname "${CROSS_SQLITE_OBJ}")"
    clang -target x86_64-linux-gnu --sysroot="${HOME}/.vmodules/linuxroot" -O2 -fPIC -w \
      -c "${VROOT}/thirdparty/sqlite/sqlite3.c" -o "${CROSS_SQLITE_OBJ}"
  fi
  PKG_CONFIG_LIBDIR="/nonexistent-cross-build" \
    v -prod -parallel-cc -os linux -arch amd64 \
      -cflags "${CROSS_SQLITE_OBJ} -Wl,--allow-shlib-undefined" \
      -o bin/lab-v-ipxe-linux-amd64 .
fi

echo "==> done"
ls -la bin/
if command -v shasum >/dev/null; then
  shasum -a 256 bin/* 2>/dev/null || true
fi

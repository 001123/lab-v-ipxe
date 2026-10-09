# iPXE ZTP

[![Version](https://img.shields.io/badge/version-0.0.5-blue?style=flat-square)](https://github.com/001123/lab-v-ipxe/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)
[![Packaging](https://img.shields.io/badge/packaging-single_binary-7C3AED?style=flat-square)](https://github.com/001123/lab-v-ipxe)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS-24292e?style=flat-square&logo=linux&logoColor=white)](https://github.com/001123/lab-v-ipxe)
[![Architecture](https://img.shields.io/badge/arch-amd64%20%7C%20arm64-10B981?style=flat-square)](https://github.com/001123/lab-v-ipxe)
[![Target OS](https://img.shields.io/badge/target_OS-Ubuntu_24.04%20%7C%2026.04-E95420?style=flat-square&logo=ubuntu&logoColor=white)](https://ubuntu.com/)

[![V](https://img.shields.io/badge/V-0.5.2-5d87a8?style=flat-square&logo=v&logoColor=white)](https://vlang.io/)
[![veb](https://img.shields.io/badge/veb-bundled_vlib-4f46e5?style=flat-square)](https://github.com/vlang/v/tree/master/vlib/veb)
[![SQLite](https://img.shields.io/badge/SQLite-3-003B57?style=flat-square&logo=sqlite&logoColor=white)](https://sqlite.org/)
[![Next.js](https://img.shields.io/badge/Next.js-16-black?style=flat-square&logo=next.js&logoColor=white)](https://nextjs.org/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5-3178C6?style=flat-square&logo=typescript&logoColor=white)](https://www.typescriptlang.org/)
[![React](https://img.shields.io/badge/React-19-20232A?style=flat-square&logo=react&logoColor=61DAFB)](https://react.dev/)
[![Tailwind CSS](https://img.shields.io/badge/Tailwind_CSS-v4-06B6D4?style=flat-square&logo=tailwindcss&logoColor=white)](https://tailwindcss.com/)
[![shadcn/ui](https://img.shields.io/badge/shadcn%2Fui-Base_UI-000000?style=flat-square&logo=shadcnui&logoColor=white)](https://ui.shadcn.com/)

A ZTP (Zero Touch Provisioning) server packaged as **a single binary**: iPXE HTTP service, Ubuntu autoinstall configuration (cloud-init), machine management backed by SQLite, and a modern admin UI (login, machine table, edit drawer, approval of unknown machines, OS image catalog, runtime info).

- **BE**: V 0.5.2 + [veb](https://github.com/veb-org/veb) (bundled in vlib), SQLite (`<data>/lab-v-ipxe.db`), single binary (`v.mod` version `0.1.0`).
- **FE**: Next.js 16 (App Router, `output: 'export'` static) + React 19 + TypeScript + Tailwind v4 + shadcn/ui (Base UI) + SWR, built into `web/out` and then **embedded directly into the binary** (`$embed_file` via `scripts/gen_embed.vsh`).
- **MVP**: Ubuntu **24.04.5** / **26.04.1** (pinned to exact point releases), **NFS boot** (kernel/initrd served by the app, rootfs via an existing NFS export on Proxmox). Storage layout per machine: **direct (ext4, default)**, **ZFS root** (ARC tuned for low-RAM machines) or **LVM**. The provider architecture is ready for other OSes (talos, suse, rocky...) and the PUBLIC HTTP boot mode (netboot=url) later.

## Workflow

```
Machine powers on → router (OpenWrt dnsmasq, iPXE via TFTP) → chain http://<app>/boot.ipxe?mac=${net0/mac}
  ├─ unknown MAC   → create a "pending" machine + waiting script (re-polls every 10s)
  ├─ pending       → waits for you to click Approve in the UI
  ├─ approved      → switches to "installing", serves the install script (NFS) + autoinstall user-data
  │                  (missing kernel/initrd → downloads the ISO from the internet, caches only ~100MB, then deletes the ISO)
  ├─ install done  → late-command phone-home POST /api/machines/installed → "installed"
  │                  (or click "Mark installed" in the UI if phone-home could not reach the app)
  └─ installed     → sanboot from local disk (prevents reinstall loops); to reinstall → Reinstall button
```

## Running in dev

```bash
mise run dev                    # both BE (:4793) + FE (:4794) in one terminal (run `mise trust` once first)
                                # kills this repo's old dev stack first (by port + cwd), waits for /healthz, then starts Next
scripts/dev.sh                  # BE only: SQLite + assets in ./tmp, listens on :4793 (dev binary built as ./tmp/lab-v-ipxe-dev)
# UI with hot-reload:  cd web && npm run dev -- -p 4794   (http://localhost:4794, proxies /api to :4793)
```

Port 4793 = "IPXE" on a phone keypad (I=4, P=7, X=9, E=3) — avoids the frequently conflicting 8080/3000.

Note: the UI inside the binary is embedded from `web/out` at **build** time — after changing the FE, to see it on `:4793` you must run `(cd web && npm run build) && v run scripts/gen_embed.vsh` and then restart the V server. `scripts/dev.sh` warns when `web/out` is missing.

Default account (auto-seeded): `admin@ipxe.local` / `admin@pwd`.

## Environment variables

| Variable | Default | Meaning |
|---|---|---|
| `LAB_V_IPXE_PORT` | `4793` | HTTP port (shared by UI + API + iPXE) |
| `LAB_V_IPXE_WEB_PORT` | `4794` | Next dev server port (used by `mise run dev` and the Info card in dev mode) |
| `LAB_V_IPXE_DATA_DIR` | dev: `./tmp`, prod: `~/.local/share/lab-v-ipxe` (XDG) | Location of SQLite (`lab-v-ipxe.db`) + `assets/` + `cache/` |
| `LAB_V_IPXE_BASE_URL` | empty (taken from the Host header) | Base URL embedded into iPXE/autoinstall scripts (can also be overridden in Settings) |
| `LAB_V_IPXE_ADMIN_EMAIL` / `LAB_V_IPXE_ADMIN_PASSWORD` | `admin@ipxe.local` / `admin@pwd` | Account seeded on first run |
| `LAB_V_IPXE_UBUNTU_ISO` | empty | Local ISO to extract kernel/initrd from (**recommended** when running on the same host as NFS). E.g.: `/srv/iso/ubuntu-26.04.1-live-server-amd64.iso` |
| `LAB_V_IPXE_UBUNTU_ASSETS_DIR` | empty | Directory that already contains `vmlinuz` + `initrd` (served directly, no download needed) |
| `LAB_V_IPXE_KEEP_ISO` | `false` | Keep the ISO after downloading it from the internet (deleted by default to save ~4GB) |

On first start the OS image catalog is seeded with **ubuntu `26.04.1`** → NFS `192.168.250.4:/srv/nfs/ubuntu-26.04.1` (default row); edit it in **Settings**.

Asset source order: **cache** (`<data>/assets/ubuntu/<ver>/`) → **assets dir** → **local ISO** → **fresh download** from `releases.ubuntu.com/<ver>/` (version `x.y.z` = pin the exact file `ubuntu-x.y.z-live-server-amd64.iso`; version `x.y` = auto-detect the latest `.N` release). The downloaded ISO is written to `.part`, its SHA256 is verified against the release's `SHA256SUMS`, and only then is it renamed and extracted. A failed version download is retried automatically at most 3 times (backoff 30s → 120s); after that, click fetch manually in Settings (or `POST /api/assets/fetch`).

> Version-skew note: kernel/initrd must match the ISO that the NFS server is mounting — so the catalog should pin exact point releases (`24.04.5`, `26.04.1`) rather than auto-latest. The export on pve and the row in Settings must point to the same release (e.g. `/srv/nfs/ubuntu-26.04.1` loop-mounting exactly the `26.04.1` ISO).

## Admin UI

- **Login** — bearer-token session (`veb.auth`), light/dark theme toggle, version badge.
- **Machines** — table of all machines with status (`pending` / `approved` / `installing` / `installed`); actions: Approve, Reinstall, Mark installed, Delete. The edit drawer covers hostname, MAC, OS image, boot mode, NFS root override, storage layout + install disk, username / password / SSH keys, and notes.
- **Settings**
  - *Global Configuration*: OS image catalog (`{OS, version, NFS export, default}` + per-row asset status / fetch button), base URL override, default SSH keys.
  - *Server*: data dir / paths and the ISO extractors detected on the host.
  - *Info*: runtime mode (production single port vs. dev `:4793` + `:4794`), process memory of backend / frontend, uptime.

## Release build (single binary)

```bash
# once for Linux builds if VROOT doesn't have the thirdparty sqlite yet:
v run "$(dirname "$(command -v v)")/../vlib/db/sqlite/install_thirdparty_sqlite.vsh"

scripts/build.sh                  # FE (web/out) → gen embed → v -prod → bin/lab-v-ipxe-{darwin-arm64,linux-amd64}
scripts/build.sh --skip-frontend  # build binaries only (reuses the existing web/out)
scripts/build.sh --host-only      # only the host (darwin-arm64) binary
scripts/build.sh --linux-only     # only the linux-amd64 cross binary
```

The script prints `ls -la bin/` and SHA256 checksums at the end.

Running the Linux binary on LXC/VPS: `LAB_V_IPXE_DATA_DIR=/var/lib/lab-v-ipxe ./lab-v-ipxe-linux-amd64` (a systemd unit is recommended, `Environment=LAB_V_IPXE_PORT=80`).

> **Runtime deps on Linux**: the binary needs `libssl3`/`libcrypto3` (V's linker always links `-lssl -lcrypto`). Ubuntu 24.04 ships it (`libssl3t64`); minimal Debian 12 needs `apt install libssl3`. Tested for real on Debian 12 (amd64).

### Cross-build notes on Apple Silicon Mac

`scripts/build.sh` already handles the following; documented here to explain why:

- `ld.lld` in the `~/.vmodules/linuxroot` sysroot is an **x86_64** binary (requires Rosetta). On arm64 machines without Rosetta → replace it with a wrapper using zig's lld (one-time):
  ```bash
  cd ~/.vmodules/linuxroot
  mv ld.lld ld.lld.x86_64-bundled.bak
  printf '#!/bin/sh\nexec zig ld.lld "$@"\n' > ld.lld && chmod +x ld.lld
  ```
- Empty `PKG_CONFIG_LIBDIR` when cross-compiling → forces use of `thirdparty/sqlite/sqlite3.c` instead of macOS pkg-config (otherwise: `sqlite3.h not found`).
- The macos→linux driver doesn't compile thirdparty `.c` inputs itself → build.sh compiles `sqlite3.c` for the target into `tmp/sqlite3-linux-amd64.o` (one-time) and passes it via `-cflags`.
- `libssl.so` in the sysroot needs symbols newer than the sysroot's glibc 2.31 → add `-Wl,--allow-shlib-undefined` (these symbols are resolved at runtime by the target distro).
- `-parallel-cc` → drop `-flto` because lld can't read bitcode from newer clang.
- None of these tricks are needed when building directly on Linux (building on LXC is also a good fallback).

## Router configuration (OpenWrt dnsmasq — just point `filename` at the app)

```uci
config match 'ipxe_stage2'
    option network 'lan'
    option match '175'                     # iPXE tag (option 175)
    option boot 'http://<ip-app>:4793/boot.ipxe?mac=${net0/mac}'
```

Standard dnsmasq equivalent: `dhcp-match=set:ipxe,175` + `dhcp-boot=tag:ipxe,http://<ip-app>:4793/boot.ipxe?mac=${net0/mac}`.

## Proxmox scripts (`scripts/proxmox/`)

Uses `secret/proxmox/credentials.env` (API token; `secret/` is gitignored), loaded by `scripts/proxmox/env.sh`.

```bash
scripts/proxmox/vm-ctl.sh list                       # list VMs
scripts/proxmox/create-test-vm.sh --recreate         # create VM 999 UEFI, MAC 52:54:00:99:00:01, net-first boot
scripts/proxmox/create-test-vm.sh --memory 2048 --mac 52:54:00:99:00:02   # "low-RAM" machine for NFS testing
scripts/proxmox/vm-ctl.sh stop 999
scripts/proxmox/vm-ctl.sh destroy 999                # asks for confirmation
```

## End-to-end ZTP test runbook

1. Prepare on pve (already in place): `/srv/nfs/ubuntu-24.04.5` + `/srv/nfs/ubuntu-26.04.1` loop-mounting the ISOs + NFS export for `192.168.250.0/24`; `nfs-kernel-server` running.
2. Run the app on a machine in the LAN (or LXC) with `LAB_V_IPXE_UBUNTU_ISO=/srv/iso/ubuntu-26.04.1-live-server-amd64.iso`.
3. Point dnsmasq's `filename`/`boot` at `http://<ip-app>:4793/boot.ipxe?mac=${net0/mac}`.
4. `scripts/proxmox/create-test-vm.sh --recreate` → VM boots into iPXE → shows up as **pending** in the UI.
5. UI → **Approve** (pick an OS image, enter hostname, SSH key, optional password — default user `ubuntu`) → the machine re-chains and starts installing (iPXE console shows the NFS script; kernel/initrd downloaded from the app).
6. Installation takes 15–40 minutes (longer with NFS + ZFS on HDD). Watch the VM console. When done, the late-command calls phone-home → the machine switches to **installed**.
7. Reboot → iPXE receives a `sanboot` script from the app → boots from local disk.
8. To reinstall: UI → **Reinstall** (status back to approved, `install_count++` so cloud-init re-runs autoinstall).

### Quick checks without a VM

```bash
curl "http://127.0.0.1:4793/healthz"                                   # {"status":"ok","db":"ok",...}
curl "http://127.0.0.1:4793/boot.ipxe?mac=bc:24:11:00:24:99"          # waiting script / install script / sanboot
curl "http://127.0.0.1:4793/os/ubuntu/26.04.1/BC:24:11:00:24:99/user-data"  # autoinstall YAML
curl -I "http://127.0.0.1:4793/assets/ubuntu/26.04.1/initrd"          # kernel/initrd
curl -X POST -d 'mac=bc:24:11:00:24:99&hostname=vm-test' http://127.0.0.1:4793/api/machines/installed
```

## HTTP API

| Method & path | Auth | Purpose |
|---|---|---|
| `GET /healthz` | public | Liveness + DB ping |
| `GET /boot.ipxe?mac=…` | public | iPXE entry point (wait / install / sanboot script) |
| `GET /os/:os/:version/:mac/{user-data,meta-data,vendor-data}` | public | cloud-init NoCloud datasource |
| `GET /assets/:os/:version/:file` | public | kernel / initrd |
| `POST /api/machines/installed` | public | Phone-home from the installer late-command |
| `POST /api/auth/login` · `POST /api/auth/logout` · `GET /api/auth/me` | login public, rest Bearer | Session |
| `GET/POST /api/machines` · `GET/PUT/DELETE /api/machines/:id` | Bearer | Machine CRUD |
| `POST /api/machines/:id/{approve,reinstall,mark-installed}` | Bearer | Lifecycle actions |
| `GET/PUT /api/settings` | Bearer | OS image catalog, base URL override, default SSH keys (`"auto"` clears) |
| `POST /api/assets/fetch` | Bearer | Fetch kernel/initrd (body `{os_name, version}` or empty = all images) |
| `GET /api/system/info` | Bearer | Runtime mode, process memory, uptime |
| `GET /*` | public | Embedded SPA |

## Technical notes

- **OS images (Settings)**: defaults are an **image list** `{OS, version, NFS export, default}` (stored in the `os_images` setting; old DBs auto-migrate the 2 keys `nfs_root_default`/`ubuntu_version` on startup). A machine picks an image when created/approved and **inherits** the NFS export from the corresponding row (per-machine overrides are kept); machines discovered via PXE for the first time get the image marked as default. Version rules: **3 parts** (`26.04.1`, `24.04.5`) = pin the exact point release, download exactly that ISO (no auto-latest — avoids drift from the NFS export); **2 parts** (`26.04`) = auto-detect the latest `.N` release. Adding a **new point release** of a supported series (e.g. `26.04.2`) = add a row in the UI/API + a new NFS export, **no code changes needed**; adding a **new series** = 1 line in `internal/providers/ubuntu/ubuntu.v` `versions()`; adding **another OS** = implement `OSProvider` (`name/display_name/versions/supports_version/assets_ready/install_script/user_data/meta_data`) + register it in `internal/server/app.v` → it automatically appears in the dropdown.
- **Boot mode**: `nfs` (default, implemented) or `http` (selectable in the API/UI, but the Ubuntu provider currently returns a "not implemented yet" error for it).
- **Storage layout**: `direct` (ext4, default), `zfs` or `lvm`. `zfs` adds late-commands writing `/etc/modprobe.d/zfs.conf` (`zfs_arc_max=512MiB`, `zfs_arc_min=128MiB`) + `update-initramfs -u` — needed for low-RAM machines. The per-machine **Install disk** field (drawer) accepts a `/dev/...` path (e.g. `/dev/nvme0n1`, `/dev/disk/by-id/...`) → rendered as `storage.layout.match.path`; leave empty = subiquity picks the largest disk, enter `auto` to reset to the default.
- **Ansible-ready**: autoinstall pre-creates `/etc/sudoers.d/90-lab-nopasswd` (NOPASSWD for the admin user) — Ubuntu 26.04 uses sudo-rs, whose auth prompt differs from the format Ansible expects, so password-based become times out. Installed machines come with sshd + python3 → run `ansible -b` right away with no extra configuration.
- **iPXE cmdline** keeps the verified settings: no `initrd=` on the kernel line (conflicts with UEFI EFI_LOAD_FILE2), `ramdisk_size=3500000`, `cloud-config-url=/dev/null`.
- **OS password**: stored as a `$6$` hash (sha512-crypt, compatible with `/etc/shadow` and cloud-init); UI passwords use bcrypt via `crypto.bcrypt`; session tokens via `veb.auth`.
- **Low-RAM machines**: use NFS boot (rootfs streamed over NFS, RAM ~300MB–4GB) — PUBLIC HTTP mode (tmpfs) only suits machines with ≥8GB and is not part of the MVP.
- **Extractor** for pulling kernel/initrd out of the ISO: `xorriso` → `7z` → `bsdtar` (macOS has bsdtar; on LXC Debian install `xorriso` or `p7zip-full`). Detected extractors are shown in Settings → Server.
- **API auth**: all `/api/*` endpoints require a Bearer token except `POST /api/auth/login` and `POST /api/machines/installed` (phone-home); `/boot.ipxe`, `/os/*`, `/assets/*`, `/healthz` are public by design.
- **SPA embedding**: the server loads the FE into memory **once at startup**. Dev builds read from `web/out` — if the FE is missing/stale, the UI cleanly returns 404 (API + iPXE keep working normally), no crash. `-prod` builds/`scripts/build.sh` require the FE output to exist at build time (gen_embed reads from `web/out`).
- **Serving Next's static export**: `webdist.resolve()` maps URL → file (`/machines` → `machines.html`, with trailing-slash stripping); RSC requests (`?_rsc=` / `RSC` header) return the `.txt` payload (`text/x-component`) so client-side navigation works; unmatched paths return `404.html` (with a proper 404 status); `/_next/static/**` is cached `immutable`, HTML/payloads `no-cache`.

## Project layout

```
main.v                      entry point (config → store → veb server)
internal/
  config/                   env vars, data dir resolution
  store/                    SQLite ORM: machines, users, settings, os_images
  boot/                     boot request + state machine + iPXE wait/sanboot scripts
  providers/                OSProvider interface
    ubuntu/                 versions, asset fetch/extract, iPXE NFS script, autoinstall YAML
  server/                   veb app, auth middleware, routes (auth/boot/machines/settings/spa), system info
  webdist/                  generated embed of web/out
  lib/                      macutils, sha512crypt
web/                        Next.js admin UI (app/, components/, hooks/, lib/)
scripts/                    dev.sh, build.sh, gen_embed.vsh, proxmox/
```

## Tests

```bash
v -check . && v fmt -verify .
v -stats test internal/
```

Includes standard test vectors for sha512-crypt (checked against `openssl passwd -6`), MAC normalization, the boot state machine, store tests, golden tests for the iPXE script + autoinstall YAML, and full integration tests for the API (login → CRUD → approve → phone-home → logout).

## Out of MVP scope (later)

- **PUBLIC HTTP** boot mode (netboot=url, client downloads the ISO from the internet) — already modelled in the API/UI, provider has an extension point for it.
- A dedicated NFS LXC instead of the pve host's export.
- Automated app deployment script for LXC.
- More OS providers: Talos Linux, SUSE Leap / Leap Micro, CentOS, Rocky...
- Multi-user + change-password page.

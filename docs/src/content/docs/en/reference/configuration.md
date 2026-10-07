---
title: Configuration & Environment Variables
description: Comprehensive reference of environment variables, directories, and database settings.
---

**iPXE ZTP** can be configured via environment variables or directly through the Web Console **Settings** page.

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `LAB_V_IPXE_PORT` | `4793` | HTTP port for backend service (serving UI, API, and `/boot.ipxe`). |
| `LAB_V_IPXE_WEB_PORT` | `4794` | Next.js development server port (used by `mise run dev`). |
| `LAB_V_IPXE_DATA_DIR` | dev: `./tmp`<br/>prod: `~/.local/share/lab-v-ipxe` | Directory where SQLite (`lab-v-ipxe.db`), assets, and ISO caches are stored. |
| `LAB_V_IPXE_BASE_URL` | *(empty)* | Public base URL embedded into iPXE boot and autoinstall scripts. If unset, inferred from the incoming `Host` HTTP header. |
| `LAB_V_IPXE_ADMIN_EMAIL` | `admin@ipxe.local` | Initial admin account email seeded on first launch. |
| `LAB_V_IPXE_ADMIN_PASSWORD` | `admin@pwd` | Initial admin account password seeded on first launch. |
| `LAB_V_IPXE_UBUNTU_ISO` | *(empty)* | Path to a local ISO file to extract kernel and initrd from (recommended if running on the same host as NFS). |
| `LAB_V_IPXE_UBUNTU_ASSETS_DIR`| *(empty)* | Path to a directory that already contains pre-extracted `vmlinuz` and `initrd` files. |
| `LAB_V_IPXE_KEEP_ISO` | `false` | When `true`, retains the downloaded Ubuntu ISO after extracting boot assets. When `false`, deletes the multi-GB ISO to save disk space. |

---

## Directory Layout

Inside `LAB_V_IPXE_DATA_DIR`:

```
<LAB_V_IPXE_DATA_DIR>/
├── lab-v-ipxe.db          # Primary SQLite database
├── lab-v-ipxe.db-wal      # SQLite Write-Ahead Log
├── lab-v-ipxe.db-shm      # Shared memory index
├── assets/                # Stored OS assets and templates
└── cache/                 # Cached vmlinuz and initrd files (~100MB per OS release)
```

---

## Production Deployment Example (Systemd)

Create `/etc/systemd/system/lab-v-ipxe.service`:

```ini
[Unit]
Description=iPXE ZTP Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/var/lib/lab-v-ipxe
Environment=LAB_V_IPXE_PORT=80
Environment=LAB_V_IPXE_DATA_DIR=/var/lib/lab-v-ipxe
Environment=LAB_V_IPXE_BASE_URL=http://192.168.1.10
ExecStart=/usr/local/bin/lab-v-ipxe
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Enable and start the service:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now lab-v-ipxe
```

# lab-v-ipxe

Server ZTP (Zero Touch Provisioning) đóng gói **1 file binary duy nhất**: dịch vụ iPXE HTTP, cấu hình autoinstall Ubuntu (cloud-init), quản lý máy bằng SQLite và UI quản trị hiện đại (login, bảng máy, drawer edit, approve máy lạ).

- **BE**: V 0.5.2 + [veb](https://github.com/veb-org/veb) (bundled trong vlib), SQLite (`db.sqlite`), single binary.
- **FE**: Vue 3 + Vite + TypeScript + Pinia + Naive UI, build xong **nhúng thẳng vào binary** (`$embed_file`).
- **MVP**: Ubuntu 24.04, **boot qua NFS** (kernel/initrd do app serve, rootfs qua NFS export có sẵn trên Proxmox), **cài root trên ZFS** (tune ARC cho máy ít RAM). Kiến trúc provider sẵn sàng cho OS khác (talos, suse, rocky...) và mode PUBLIC HTTP (netboot=url) sau này.

## Luồng hoạt động

```
Máy bật nguồn → router (OpenWrt dnsmasq, iPXE qua TFTP) → chain http://<app>/boot.ipxe?mac=${net0/mac}
  ├─ MAC lạ        → tạo máy "pending" + script chờ (tự poll lại mỗi 10s)
  ├─ pending       → chờ bạn bấm Approve trên UI
  ├─ approved      → chuyển "installing", serve script cài (NFS) + user-data autoinstall
  │                  (thiếu kernel/initrd → tự tải ISO từ internet, chỉ cache ~100MB rồi xoá ISO)
  ├─ đang cài xong → late-command phone-home POST /api/machines/installed → "installed"
  └─ installed     → sanboot từ ổ đĩa (chống cài lại vòng lặp); muốn cài lại → nút Reinstall
```

## Chạy dev

```bash
utils/dev.sh                    # SQLite + assets trong ./tmp, lắng nghe :8080
# UI có hot-reload:  cd web && npm run dev   (http://localhost:5173, proxy /api về :8080)
```

Tài khoản mặc định (seed tự động): `admin@ipxe.local` / `admin@pwd`.

## Biến môi trường

| Biến | Mặc định | Ý nghĩa |
|---|---|---|
| `LAB_V_IPXE_PORT` | `8080` | Cổng HTTP |
| `LAB_V_IPXE_DATA_DIR` | dev: `./tmp`, prod: `~/.local/share/lab-v-ipxe` (XDG) | Nơi chứa SQLite + assets |
| `LAB_V_IPXE_BASE_URL` | rỗng (lấy từ Host header) | URL gốc nhúng vào script iPXE/autoinstall |
| `LAB_V_IPXE_ADMIN_EMAIL` / `LAB_V_IPXE_ADMIN_PASSWORD` | `admin@ipxe.local` / `admin@pwd` | Tài khoản seed lần đầu |
| `LAB_V_IPXE_UBUNTU_ISO` | rỗng | ISO local để trích kernel/initrd (**khuyến nghị** khi cùng máy với NFS). VD: `/srv/iso/ubuntu-24.04-live-server-amd64.iso` |
| `LAB_V_IPXE_UBUNTU_ASSETS_DIR` | rỗng | Thư mục đã có sẵn `vmlinuz` + `initrd` (serve trực tiếp, không cần tải) |
| `LAB_V_IPXE_KEEP_ISO` | `false` | Giữ lại ISO sau khi tải từ internet (mặc định xoá để tiết kiệm ~4GB) |

Thứ tự nguồn assets: **cache** (`<data>/assets/ubuntu/<ver>/`) → **assets dir** → **ISO local** → **tải mới** từ `releases.ubuntu.com/noble/` (tự dò bản `24.04.x` mới nhất).

> Lưu ý version-skew: kernel/initrd phải khớp với ISO mà NFS server đang mount. Khi pve export `/srv/nfs/ubuntu-24.04` từ 1 ISO cụ thể, hãy dùng `LAB_V_IPXE_UBUNTU_ISO` trỏ đúng ISO đó.

## Build release (1 file binary)

```bash
# một lần cho build Linux nếu VROOT chưa có thirdparty sqlite:
v run "$(dirname "$(command -v v)")/../vlib/db/sqlite/install_thirdparty_sqlite.vsh"

utils/build.sh                  # FE → gen embed → v -prod → bin/lab-v-ipxe-{darwin-arm64,linux-amd64}
utils/build.sh --skip-frontend  # chỉ build binary
```

Binary Linux chạy trên LXC/VPS: `LAB_V_IPXE_DATA_DIR=/var/lib/lab-v-ipxe ./lab-v-ipxe-linux-amd64` (khuyến nghị systemd unit, `Environment=LAB_V_IPXE_PORT=80`).

> **Runtime deps trên Linux**: binary cần `libssl3`/`libcrypto3` (do linker của V luôn link `-lssl -lcrypto`). Ubuntu 24.04 có sẵn (`libssl3t64`); Debian 12 tối giản cần `apt install libssl3`. Đã test chạy thật trên Debian 12 (amd64).

### Lưu ý cross-build trên Mac Apple Silicon

`utils/build.sh` đã xử lý sẵn các điểm sau; ghi lại để hiểu vì sao:

- `ld.lld` trong sysroot `~/.vmodules/linuxroot` là binary **x86_64** (cần Rosetta). Máy arm64 không có Rosetta → thay bằng wrapper dùng lld của zig (một lần):
  ```bash
  cd ~/.vmodules/linuxroot
  mv ld.lld ld.lld.x86_64-bundled.bak
  printf '#!/bin/sh\nexec zig ld.lld "$@"\n' > ld.lld && chmod +x ld.lld
  ```
- `PKG_CONFIG_LIBDIR` rỗng khi cross → buộc dùng `thirdparty/sqlite/sqlite3.c` thay vì pkg-config của macOS (nếu không: `sqlite3.h not found`).
- Driver macos→linux không tự biên dịch input `.c` của thirdparty → build.sh tự compile `sqlite3.c` cho target vào `tmp/sqlite3-linux-amd64.o` (một lần) rồi truyền qua `-cflags`.
- `libssl.so` trong sysroot cần symbol mới hơn glibc 2.31 của sysroot → thêm `-Wl,--allow-shlib-undefined` (các symbol này được resolve lúc chạy bởi distro đích).
- `-parallel-cc` → bỏ `-flto` vì lld không đọc được bitcode của clang mới.
- Không cần các mẹo trên khi build trực tiếp trên Linux (build trên LXC cũng là phương án dự phòng tốt).

## Cấu hình router (OpenWrt dnsmasq — chỉ cần trỏ `filename` về app)

```uci
config match 'ipxe_stage2'
    option network 'lan'
    option match '175'                     # tag iPXE (option 175)
    option boot 'http://<ip-app>:8080/boot.ipxe?mac=${net0/mac}'
```

Tương đương dnsmasq chuẩn: `dhcp-match=set:ipxe,175` + `dhcp-boot=tag:ipxe,http://<ip-app>:8080/boot.ipxe?mac=${net0/mac}`.

## Scripts Proxmox (`utils/proxmox/`)

Dùng `secret/proxmox/credentials.env` (API token; `secret/` đã gitignore).

```bash
utils/proxmox/vm-ctl.sh list                       # liệt kê VM
utils/proxmox/create-test-vm.sh --recreate         # tạo VM 999 UEFI, MAC 52:54:00:99:00:01, boot net-first
utils/proxmox/create-test-vm.sh --memory 2048 --mac 52:54:00:99:00:02   # máy "ít RAM" test NFS
utils/proxmox/vm-ctl.sh stop 999
utils/proxmox/vm-ctl.sh destroy 999                # có xác nhận
```

## Runbook test ZTP end-to-end

1. Chuẩn bị trên pve (đã có sẵn): `/srv/nfs/ubuntu-24.04` loop-mount ISO + export NFS cho `192.168.250.0/24`; `nfs-kernel-server` chạy.
2. Chạy app trên máy trong LAN (hoặc LXC) với `LAB_V_IPXE_UBUNTU_ISO=/srv/iso/ubuntu-24.04-live-server-amd64.iso`.
3. Trỏ `filename`/`boot` của dnsmasq về `http://<ip-app>:8080/boot.ipxe?mac=${net0/mac}`.
4. `utils/proxmox/create-test-vm.sh --recreate` → VM boot vào iPXE → xuất hiện **pending** trên UI.
5. UI → **Approve** (nhập hostname, SSH key, password tùy chọn — mặc định `ubuntu`) → máy tự chain lại và bắt đầu cài (console iPXE hiển thị script NFS; kernel/initrd tải từ app).
6. Quá trình cài 15–40 phút (NFS + ZFS trên HDD càng lâu). Theo dõi trên console VM. Cài xong, late-command gọi phone-home → máy chuyển **installed**.
7. Reboot → iPXE nhận script `sanboot` từ app → boot từ ổ đĩa.
8. Muốn cài lại: UI → **Reinstall** (status về approved, `install_count++` để cloud-init chạy lại autoinstall).

### Kiểm tra nhanh không cần VM

```bash
curl "http://127.0.0.1:8080/boot.ipxe?mac=bc:24:11:00:24:99"          # script chờ / script cài / sanboot
curl "http://127.0.0.1:8080/os/ubuntu/24.04/BC:24:11:00:24:99/user-data"  # YAML autoinstall
curl -I "http://127.0.0.1:8080/assets/ubuntu/24.04/initrd"            # kernel/initrd
curl -X POST -d 'mac=bc:24:11:00:24:99&hostname=vm-test' http://127.0.0.1:8080/api/machines/installed
```

## Ghi chú kỹ thuật

- **ZFS root**: `storage.layout.name: zfs`; late-commands ghi `/etc/modprobe.d/zfs.conf` (`zfs_arc_max=512MB`, `arc_min=128MB`) + `update-initramfs -u` — cần cho máy ít RAM. Máy quá nhỏ có thể chọn layout `direct`/`lvm` per-máy trong drawer.
- **Cmdline iPXE** giữ nguyên các điểm đã kiểm chứng: không đặt `initrd=` trên dòng kernel (xung đột UEFI EFI_LOAD_FILE2), `ramdisk_size=3500000`, `cloud-config-url=/dev/null`.
- **Password OS**: lưu hash `$6$` (sha512-crypt, tương thích `/etc/shadow` và cloud-init); mật khẩu UI dùng bcrypt qua `crypto.bcrypt`; token phiên qua `veb.auth`.
- **Máy ít RAM**: dùng NFS boot (rootfs stream qua NFS, RAM ~300MB–4GB) — mode PUBLIC HTTP (tmpfs) chỉ hợp máy ≥8GB và chưa làm trong MVP.
- **Extractor** khi trích kernel/initrd từ ISO: `xorriso` → `7z` → `bsdtar` (macOS có bsdtar; LXC Debian cài `xorriso` hoặc `p7zip-full`).
- **API**: toàn bộ endpoint `/api/*` cần Bearer token; `/boot.ipxe`, `/os/*`, `/assets/*`, `POST /api/machines/installed` (phone-home) là public theo thiết kế.

## Test

```bash
v -check . && v fmt -verify .
v -stats test . macutils/ store/ sha512crypt/ core/ providers/
```

Bao gồm test vectors chuẩn cho sha512-crypt (đối chiếu `openssl passwd -6`), golden test cho script iPXE + YAML autoinstall, và integration test đầy đủ cho API (login → CRUD → approve → phone-home → logout).

## Ngoài phạm vi MVP (để sau)

- Mode **PUBLIC HTTP** (netboot=url, client tải ISO từ internet) — provider đã có sẵn chỗ mở rộng.
- LXC NFS riêng thay cho export của host pve.
- Script deploy app lên LXC tự động.
- Thêm OS provider: Talos Linux, SUSE Leap / Leap Micro, CentOS, Rocky...
- Multi-user + trang đổi mật khẩu.

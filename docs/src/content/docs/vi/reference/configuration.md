---
title: Cấu Hình & Biến Môi Trường
description: Toàn tập tham chiếu các biến môi trường, thư mục dữ liệu và cấu hình máy chủ.
---

**iPXE ZTP** có thể được cấu hình linh hoạt thông qua các biến môi trường hệ thống hoặc trực tiếp từ trang **Settings** trên Web Console.

## Danh Sách Biến Môi Trường

| Biến | Giá trị mặc định | Mô tả chi tiết |
|---|---|---|
| `LAB_V_IPXE_PORT` | `4793` | Cổng HTTP của backend (phục vụ giao diện Web, API và kịch bản `/boot.ipxe`). |
| `LAB_V_IPXE_WEB_PORT` | `4794` | Cổng máy chủ phát triển Next.js (sử dụng bởi lệnh `mise run dev`). |
| `LAB_V_IPXE_DATA_DIR` | dev: `./tmp`<br/>prod: `~/.local/share/lab-v-ipxe` | Thư mục lưu cơ sở dữ liệu SQLite (`lab-v-ipxe.db`), assets và bộ đệm ISO. |
| `LAB_V_IPXE_BASE_URL` | *(để trống)* | Đường dẫn URL công khai nhúng vào script iPXE và autoinstall. Mặc định tự động nhận từ header `Host`. |
| `LAB_V_IPXE_ADMIN_EMAIL` | `admin@ipxe.local` | Email tài khoản quản trị viên khởi tạo lần đầu. |
| `LAB_V_IPXE_ADMIN_PASSWORD` | `admin@pwd` | Mật khẩu tài khoản quản trị viên khởi tạo lần đầu. |
| `LAB_V_IPXE_UBUNTU_ISO` | *(để trống)* | Đường dẫn file ISO cục bộ trên máy để trích xuất kernel/initrd (khuyến nghị khi chạy chung máy với NFS). |
| `LAB_V_IPXE_UBUNTU_ASSETS_DIR`| *(để trống)* | Đường dẫn thư mục chứa sẵn các file `vmlinuz` và `initrd` đã giải nén. |
| `LAB_V_IPXE_KEEP_ISO` | `false` | Nếu là `true`, giữ lại file ISO Ubuntu sau khi trích xuất. Mặc định là `false` để xóa file ISO nhiều GB giúp tiết kiệm đĩa. |

---

## Cấu Trúc Thư Mục Dữ Liệu

Bên trong `LAB_V_IPXE_DATA_DIR`:

```
<LAB_V_IPXE_DATA_DIR>/
├── lab-v-ipxe.db          # File cơ sở dữ liệu SQLite chính
├── lab-v-ipxe.db-wal      # Nhật ký Write-Ahead Log của SQLite
├── lab-v-ipxe.db-shm      # File chỉ mục bộ nhớ chia sẻ
├── assets/                # Chứa template OS và tài nguyên phụ trợ
└── cache/                 # Bộ nhớ đệm chứa kernel và initrd (~100MB mỗi bản OS)
```

---

## Mẫu Cấu Hình Chạy Thực Tế (Systemd Service)

Tạo file `/etc/systemd/system/lab-v-ipxe.service`:

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

Kích hoạt và khởi chạy dịch vụ:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now lab-v-ipxe
```

---
title: Giới Thiệu
description: Tổng quan kiến trúc và các khái niệm cốt lõi của iPXE ZTP.
---

**iPXE ZTP** là máy chủ tự động hóa cài đặt hệ điều hành qua mạng (Zero Touch Provisioning) tất-cả-trong-một, được đóng gói thành **một file thực thi nhị phân duy nhất**. Dự án kết hợp dịch vụ iPXE boot qua HTTP, bộ sinh cấu hình autoinstall cloud-init cho Ubuntu, cơ sở dữ liệu SQLite quản lý máy chủ và giao diện web console hiện đại.

```
Máy bật nguồn → router (OpenWrt dnsmasq, iPXE qua TFTP) → chain http://<app>/boot.ipxe?mac=${net0/mac}
  ├─ MAC chưa biết → tạo máy ở trạng thái "pending" + script chờ (hỏi lại sau mỗi 10 giây)
  ├─ pending       → chờ quản trị viên bấm Duyệt (Approve) trên giao diện web
  ├─ approved      → chuyển sang "installing", trả về script cài (NFS) + autoinstall user-data
  │                  (chưa có kernel/initrd → tự tải ISO, trích xuất ~100MB, xóa file ISO)
  ├─ install done  → late-command gửi POST /api/machines/installed → "installed"
  │                  (hoặc bấm thủ công "Mark installed" trên web)
  ├─ installed     → sanboot từ ổ cứng cục bộ (ngăn chặn vòng lặp cài lại khi khởi động)
  └─ Day-1 ready   → 🚀 Sẵn sàng cho Ansible (khóa SSH, sudo NOPASSWD, Python 3, APT mirror tối ưu)
```

## Thiết Kế Kiến Trúc

Dự án được xây dựng dựa trên triết lý tối giản, hiệu năng tối đa và không phụ thuộc runtime ngoài:

### 1. Backend (`v.mod`, `main.v`)
- Viết bằng ngôn ngữ **V (0.5.2)** kết hợp framework web **veb** tích hợp sẵn trong thư viện chuẩn (`vlib`).
- Biên dịch trực tiếp thành mã nhị phân C native cực kỳ nhẹ và nhanh.
- Tích hợp sẵn cơ sở dữ liệu SQLite 3 (chế độ `WAL`) kèm cơ chế auto-migration.
- Cung cấp script iPXE động (`/boot.ipxe`), file cấu hình cài đặt Ubuntu autoinstall (`/autoinstall/:mac/user-data`) và các REST API tại `/api/*`.

### 2. Frontend (`web/`)
- Xây dựng bằng **Next.js 16** (App Router, cấu hình xuất tĩnh `output: 'export'`).
- React 19 + TypeScript + Tailwind CSS v4 + **shadcn/ui** (Base UI).
- Đồng bộ dữ liệu thời gian thực và cập nhật giao diện mượt mà với **SWR**.
- Toàn bộ kết quả build (`web/out`) được nhúng trực tiếp vào file nhị phân V bằng `$embed_file` thông qua script sinh mã `scripts/gen_embed.vsh`.

### 3. Động Cơ Cài Đặt & Tự Động Hóa (Provisioning & Day-1 Engine)
- **Hệ điều hành mục tiêu**: Ubuntu Server 24.04.5 LTS & 26.04.1 (phiên bản point-release cố định).
- **Giao thức khởi động**: NFS boot mang lại tốc độ truyền tải cao trong mạng nội bộ.
- **Bộ nhớ đệm ISO thông minh**: Tự động tải file ISO Ubuntu chính thức theo nhu cầu, chỉ trích xuất ~100MB chứa `vmlinuz` cùng `initrd` để lưu cache và xóa ngay file ISO dung lượng lớn.
- **Phân vùng ổ cứng**: Các mẫu cấu hình sẵn: `direct` (ext4), `zfs` root (tự động tối ưu tham số ARC theo dung lượng RAM) hoặc `lvm`.
- **Cấu hình APT Mirror linh hoạt**: Cho phép chỉnh sửa URL mirror hoặc dùng cache LAN (như `apt-cacher-ng`), tích hợp tính năng probe đo latency trực tiếp từ Web UI.
- **Bàn giao Day-1 hoàn chỉnh**: Cài đặt sẵn Python 3, cấu hình NOPASSWD trong `/etc/sudoers.d/90-lab-nopasswd` giúp các playbook Ansible chạy ngay lập tức mà không cần bất kỳ bước cấu hình thủ công nào sau khi cài xong.

## Bước Tiếp Theo

Xem hướng dẫn [Cài Đặt Nhanh](/lab-v-ipxe/vi/getting-started/quickstart/) để chạy môi trường phát triển trên máy tính của bạn trong vài phút.

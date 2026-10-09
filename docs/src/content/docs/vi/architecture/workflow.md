---
title: Vòng Đời Máy Chủ & Quy Trình
description: Chi tiết vòng đời quản lý máy tự động Zero Touch Provisioning và các trạng thái hệ thống.
---

Thế mạnh nổi bật của **iPXE ZTP** là khả năng quản lý vòng đời máy hoàn toàn tự động. Mỗi máy chủ (vật lý hoặc ảo hóa) sẽ chuyển đổi qua các trạng thái rõ ràng, có thể kiểm toán từ lúc cắm điện lần đầu cho đến khi sẵn sàng vận hành.

## Sơ Đồ Máy Trạng Thái (State Machine)

```
                     [ Máy Bật Nguồn ]
                            │
                            ▼
                   Chainload iPXE qua DHCP
                            │
               ┌────────────┴────────────┐
               │ MAC đã có trong SQLite? │
               └────────────┬────────────┘
                     Chưa   │     Đã có
         ┌──────────────────┘     └──────────────────┐
         ▼                                           ▼
   [ PENDING ]                               Kiểm tra trạng thái máy
  (Hỏi lại /boot.ipxe                                │
    mỗi 10 giây)                                     ├─ status == 'approved'
         │                                           │       │
         │ Quản trị viên                             │       ▼
         │ bấm "Duyệt"                               │   [ INSTALLING ]
         ▼                                           │  (Trả kernel NFS +
   [ APPROVED ] ◄────────────────────────────────────┘   cloud-init user-data)
         │                                                   │
         │ Chu kỳ hỏi tiếp theo sẽ boot                      │ Quá trình cài hoàn tất
         ▼                                                   │ (late-command phone-home)
   [ INSTALLING ]                                            ▼
         │                                             [ INSTALLED ]
         └───────────────────────────────────────────► (Khởi động lại → sanboot
                                                        từ ổ cứng cục bộ)
```

## Chi Tiết Các Giai Đoạn

### 1. Nhận Diện Ban Đầu (`pending`)
- Khi máy chủ hoặc VM khởi động, card mạng (NIC) kích hoạt yêu cầu PXE qua broadcast.
- DHCP server nội bộ (ví dụ: OpenWrt `dnsmasq`) hướng dẫn máy tải bootloader iPXE.
- iPXE gửi yêu cầu tới ứng dụng:
  ```bash
  chain http://<SERVER_IP>:4793/boot.ipxe?mac=${net0/mac}
  ```
- Nếu địa chỉ MAC chưa từng xuất hiện, máy chủ tạo bản ghi mới với trạng thái `pending` và trả về kịch bản chờ:
  ```bash
  #!ipxe
  echo Machine ${mac} registered. Waiting for approval...
  sleep 10
  chain http://<SERVER_IP>:4793/boot.ipxe?mac=${mac}
  ```

### 2. Quản Trị Viên Phê Duyệt (`approved`)
- Quản trị viên mở Web Console và thấy máy mới hiển thị nổi bật trong hàng chờ.
- Tại đây bạn có thể cấu hình:
  - **Tên máy (Hostname)**: vd `worker-01.lab.local`
  - **Địa chỉ IP**: Cấp tĩnh hoặc qua DHCP
  - **Hệ điều hành**: Ubuntu 24.04.5 hoặc 26.04.1
  - **Mẫu phân vùng đĩa**: `direct` (ext4), `zfs` hoặc `lvm`
- Bấm **Duyệt (Approve)** để chuyển trạng thái sang `approved`.

### 3. Tiến Hành Cài Đặt (`installing`)
- Ở chu kỳ thăm dò 10 giây tiếp theo, server phát hiện máy đã được `approved`.
- Server tự động chuyển trạng thái sang `installing` và gửi kịch bản boot nạp nhân hệ điều hành:
  ```bash
  #!ipxe
  kernel nfs://${NFS_SERVER}/${NFS_EXPORT}/casper/vmlinuz ip=dhcp autoinstall ds=nocloud-net;s=http://${SERVER_IP}:4793/autoinstall/${mac}/
  initrd nfs://${NFS_SERVER}/${NFS_EXPORT}/casper/initrd
  boot
  ```
- Trình cài đặt Ubuntu Subiquity tải cấu hình autoinstall được sinh động tại `/autoinstall/:mac/user-data`.

### 4. Báo Hoàn Tất & Khởi Động An Toàn (`installed`)
- Sau khi Subiquity cài đặt xong toàn bộ gói và phân vùng, lệnh `late-commands` của cloud-init sẽ gọi phone-home:
  ```bash
  curl -fsS -X POST http://${SERVER_IP}:4793/api/machines/installed \
    -H "Content-Type: application/json" \
    -d '{"mac": "..."}'
  ```
- Server ghi nhận máy sang trạng thái `installed`.
- Khi máy khởi động lại và PXE hỏi `/boot.ipxe`, server trả về:
  ```bash
  #!ipxe
  sanboot --no-describe --drive 0x80
  ```
  Lệnh này bàn giao quyền kiểm soát ngay cho ổ cứng đầu tiên của máy, triệt tiêu nguy cơ máy bị rơi vào vòng lặp cài lại liên tục.

### 5. Sẵn Sàng Cho Ansible Ngay Lập Tức (Day-1 Integration)
Một điểm cộng vượt trội của **lab-v-ipxe** so với các hệ thống PXE truyền thống là khả năng **tự động hóa hoàn toàn từ Day-0 sang Day-1**:
- **Sudo NOPASSWD tự động**: File `/etc/sudoers.d/90-lab-nopasswd` được sinh sẵn qua `late-commands`. Điều này giải quyết triệt để vấn đề `sudo-rs` (mặc định trên Ubuntu 24.04/26.04) làm timeout prompt mật khẩu khi Ansible thực thi `become: yes`.
- **SSH Key & Python 3**: Khóa SSH công khai của quản trị viên được tích hợp thẳng vào `~/.ssh/authorized_keys`, và môi trường đã có sẵn Python 3 (`/usr/bin/python3`).
- **Tốc độ APT tối ưu**: File `/etc/apt/sources.list.d/ubuntu.sources` đã được cấu hình trỏ thẳng về mirror tối ưu (hoặc mirror nội bộ trong LAN).
- **Kiểm tra tức thì không cần cấu hình thêm**:
  ```bash
  # Kiểm tra kết nối và thu thập facts
  ansible all -i '<machine-ip>,' -m ping -u ubuntu

  # Nâng quyền root qua sudo mà không cần nhập mật khẩu
  ansible all -i '<machine-ip>,' -m command -a 'whoami' -u ubuntu -b
  ```
Ngay khi trạng thái trên Web Console chuyển sang `installed`, các pipeline CI/CD hoặc playbook Ansible có thể tự động nhảy vào cài đặt Kubernetes (K3s), Docker hoặc Tailscale mà không cần bất kỳ sự can thiệp thủ công nào của con người.

### 6. Cài Đặt Lại (Reinstall)
Bất cứ khi nào bạn muốn cài mới lại một máy, chỉ cần bấm nút **Cài Lại (Reinstall)** trong Web Console. Trạng thái máy sẽ quay về `approved` và tự động cài đặt lại trong lần khởi động tiếp theo.

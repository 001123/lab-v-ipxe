---
title: Lưu Trữ & Chế Độ Khởi Động
description: Tìm hiểu cơ chế boot qua NFS, lưu đệm thông minh ISO và các mẫu phân vùng ổ cứng.
---

**iPXE ZTP** tối ưu hóa đồng thời tốc độ truyền tải nạp hệ điều hành qua mạng nội bộ và cấu trúc phân vùng ổ đĩa vật lý của máy đích.

## Kiến Trúc Khởi Động: NFS vs HTTP

Quá trình boot qua mạng của các bản phân phối Linux hiện đại đòi hỏi phải tải nhân kernel (`vmlinuz`), ramdisk khởi tạo (`initrd`) và mount hệ thống file gốc (`casper/filesystem.squashfs`).

### Chế Độ Boot NFS (Mặc định)
Trong mạng gia đình (homelab) hoặc trung tâm dữ liệu doanh nghiệp, **NFS (Network File System)** mang lại băng thông vượt trội so với việc giải nén stream HTTP:
- iPXE nạp trực tiếp kernel và initrd (~100MB) qua giao thức NFS.
- Nhân Linux mount hệ thống tệp cài đặt sống qua NFS bằng tham số dòng lệnh kernel:
  `root=/dev/nfs nfsroot=${NFS_SERVER}:${NFS_PATH} ip=dhcp boot=casper`
- Toàn bộ quá trình cài đặt hoàn tất chỉ trong khoảng 2–3 phút qua mạng Gigabit LAN.

### Cơ Chế Lưu Đệm ISO Thông Minh (Smart ISO Cache)
Thay vì bắt quản trị viên phải trích xuất thủ công hoặc lưu trữ các file ISO nặng hàng Gigabyte:
1. Khi có yêu cầu cài đặt phiên bản Ubuntu mới (ví dụ: `24.04.5` hoặc `26.04.1`), máy chủ sẽ tự động tải file ISO chính thức từ Canonical.
2. Hệ thống trích xuất duy nhất các file thiết yếu phục vụ boot mạng: `casper/vmlinuz` và `casper/initrd`.
3. Các file trích xuất (~100MB) được lưu vào thư mục cache cục bộ (`<data>/cache/`).
4. File ISO gốc nặng nhiều GB được xóa ngay lập tức để tiết kiệm tối đa dung lượng ổ cứng.

---

## Các Mẫu Phân Vùng Ổ Cứng (Storage Presets)

Trong quá trình duyệt hoặc chỉnh sửa thông tin máy chủ trên Web UI, bạn có thể chọn một trong ba cấu trúc đĩa:

### 1. Direct (ext4, Mặc định)
Cấu trúc tiêu chuẩn, gọn nhẹ và tương thích cao nhất cho máy chủ thông thường và máy ảo:
- **Phân vùng 1**: 1 GB EFI System Partition (`/boot/efi`, FAT32).
- **Phân vùng 2**: Toàn bộ dung lượng còn lại định dạng `ext4` mount tại `/`.
- **Ưu điểm**: Không tốn tài nguyên phụ, tương thích 100% phần cứng, không yêu cầu module kernel đặc thù.

### 2. ZFS on Root
Thiết kế cho các hệ thống đòi hỏi độ tin cậy cấp doanh nghiệp, snapshot tức thời và bảo toàn dữ liệu:
- **Cấu trúc pool**: Root pool ZFS (`rpool/ROOT/ubuntu`).
- **Tối ưu bộ nhớ ARC**: Bộ nhớ đệm ZFS ARC nếu không giới hạn có thể chiếm hết RAM của máy. **iPXE ZTP** tự động tính toán và cấu hình tham số `/etc/modprobe.d/zfs.conf`:
  ```ini
  # Tự động tính toán theo dung lượng RAM thực tế của máy đích
  options zfs zfs_arc_max=2147483648
  ```
  Nhờ đó ngăn chặn triệt để tình trạng tràn bộ nhớ (OOM) trên các máy tính mini-PC hoặc node homelab RAM hạn chế.

### 3. LVM (Logical Volume Manager)
Phù hợp với các hệ thống cần khả năng thay đổi kích thước phân vùng linh hoạt trong quá trình vận hành:
- **Volume Group**: `vg_ubuntu`
- **Logical Volumes**:
  - `lv_root`: Định dạng ext4 gắn vào `/`.
  - `lv_swap`: Phân vùng swap được định kích thước linh hoạt theo RAM.
- **Ưu điểm**: Mở rộng dung lượng online, hỗ trợ thin provisioning.

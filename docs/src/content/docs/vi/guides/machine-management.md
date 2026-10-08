---
title: Quản Trị Máy Chủ & Giao Diện Web
description: Quản lý danh sách máy, duyệt thiết bị mới phát hiện và điều phối cài đặt từ Web Console.
---

Giao diện **Web Console** của iPXE ZTP cung cấp trung tâm điều hành trực quan, theo dõi theo thời gian thực toàn bộ máy chủ vật lý và máy ảo trong hạ tầng của bạn.

## Tổng Quan Bảng Điều Khiển

Sau khi đăng nhập bằng tài khoản quản trị viên (`admin@ipxe.local`), màn hình hiển thị:
- **Thẻ trạng thái (Status Cards)**: Đếm tổng số máy, số máy đang chờ duyệt (`pending`), đang cài (`installing`) và đã hoàn tất (`installed`).
- **Sức khỏe hệ thống**: Dung lượng RAM sử dụng, tải CPU và thời gian hoạt động liên tục (uptime) của dịch vụ iPXE ZTP.
- **Bảng danh sách máy (Machine Table)**: Danh mục máy với tốc độ tìm kiếm nhanh theo địa chỉ MAC, hostname hoặc IP.

---

## 1. Duyệt Máy Mới Đang Chờ (`pending`)

Khi một máy chủ vật lý mới cắm điện và nạp iPXE lần đầu, máy sẽ tự đăng ký vào hệ thống với trạng thái **`pending`**.

1. Tại bảng **Machines**, bạn sẽ thấy huy hiệu `Pending` màu vàng.
2. Bấm nút **Duyệt (Approve)** hoặc click vào dòng của máy để mở drawer cấu hình chi tiết.
3. Điền các tham số cài đặt cho máy:
   - **Tên máy (Hostname)**: vd `k8s-worker-01`.
   - **Cấp phát IP**: Chọn nhận qua **DHCP** hoặc nhập **IP tĩnh / Netmask / Gateway / DNS**.
   - **Phiên bản OS**: Chọn bản phát hành Ubuntu mong muốn (vd `24.04.5`).
   - **Mẫu phân vùng**: Chọn `direct` (ext4), `zfs` root hoặc `lvm`.
   - **Giữ iPXE ưu tiên đầu trong UEFI**: Mặc định bật. Giữ nguyên vị trí số 1 của PXE/iPXE trong BootOrder của UEFI sau khi cài Ubuntu (đặt Ubuntu ở vị trí số 2), giúp máy luôn sẵn sàng cho Zero-Touch Provisioning / Reinstall.
   - **SSH Public Key**: Dán SSH key công khai của bạn để đăng nhập root không cần mật khẩu.
4. Bấm **Xác Nhận Duyệt (Confirm Approval)**.

Trạng thái máy chuyển sang `approved`. Trong vòng tối đa 10 giây, máy trạm đích sẽ tự phát hiện lệnh duyệt, bắt đầu tải kernel/initrd và tự động cài đặt.

---

## 2. Theo Dõi Tiến Trình Cài Đặt

Khi Subiquity đang định dạng đĩa và tải các gói cài đặt, trạng thái máy hiển thị là **`installing`**.
- Sau khi cài đặt hoàn tất, script `late-commands` của cloud-init sẽ tự động gọi HTTP POST báo về `/api/machines/installed`.
- Trạng thái trên giao diện chuyển sang màu xanh lá: **`installed`**.

> **Chuyển thủ công**: Trong trường hợp card mạng của máy mới nằm trong VLAN bị chặn đường truyền HTTP về máy chủ lúc cài xong, quản trị viên có thể bấm trực tiếp nút **Đánh dấu đã cài (Mark installed)** trên web console.

---

## 3. Kích Hoạt Cài Lại (Reinstallation)

Để xóa trắng và cài lại từ đầu một máy đã vận hành:
1. Tìm máy trong bảng danh sách.
2. Bấm vào menu hành động (`...`) và chọn **Cài Lại (Reinstall)**.
3. Máy chủ sẽ đưa trạng thái về `approved`.
4. Khởi động lại máy (qua IPMI, Wake-on-LAN hoặc nút nguồn vật lý). Khi boot qua mạng, máy sẽ tự động cài mới lại toàn bộ hệ điều hành.

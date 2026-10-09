---
title: Tham Chiếu REST API
description: Đặc tả chi tiết các endpoint API quản trị và dịch vụ boot của iPXE ZTP.
---

Backend của **iPXE ZTP** cung cấp các REST API định dạng JSON phục vụ giao diện Web Console và các script tự động hóa, cùng các handler sinh kịch bản boot mạng động.

## Cơ Chế Xác Thực

Tất cả các endpoint bắt đầu bằng `/api/*` (ngoại trừ đăng nhập, kiểm tra sức khỏe và callback hoàn tất cài đặt) đều yêu cầu cookie phiên đăng nhập hợp lệ nhận từ `/api/auth/login`.

### 1. Nhóm API Xác Thực

#### `POST /api/auth/login`
Đăng nhập tài khoản quản trị viên.
- **Request Body**:
  ```json
  {
    "email": "admin@ipxe.local",
    "password": "admin@pwd"
  }
  ```
- **Response**: Thiết lập cookie `lab_v_ipxe_session` (HTTP-only) và trả về thông tin người dùng.

#### `POST /api/auth/logout`
Hủy phiên đăng nhập hiện tại.

#### `GET /api/auth/me`
Lấy thông tin tài khoản đang đăng nhập.

---

## 2. Nhóm API Quản Lý Máy Chủ

#### `GET /api/machines`
Lấy danh sách toàn bộ các máy đã đăng ký trong hệ thống.
- **Response mẫu**:
  ```json
  [
    {
      "id": 1,
      "mac": "52:54:00:12:34:56",
      "hostname": "node-01.lab.local",
      "status": "installed",
      "ip": "192.168.1.50",
      "os": "ubuntu-24.04.5",
      "storage_layout": "direct",
      "created_at": 1718000000,
      "updated_at": 1718000500
    }
  ]
  ```

#### `POST /api/machines`
Thêm mới một máy thủ công vào hệ thống.

#### `GET /api/machines/:id`
Lấy chi tiết cấu hình của một máy theo ID.

#### `PUT /api/machines/:id`
Cập nhật thông tin máy (hostname, IP, layout phân vùng đĩa, phiên bản OS, SSH key).

#### `DELETE /api/machines/:id`
Xóa máy khỏi danh mục quản lý.

#### `POST /api/machines/:id/approve`
Phê duyệt máy đang ở trạng thái `pending` chuyển sang `approved`.

#### `POST /api/machines/:id/reinstall`
Đưa máy đã cài (`installed`) trở lại trạng thái `approved` để kích hoạt cài mới trong lần boot kế tiếp.

#### `POST /api/machines/:id/mark-installed`
Chuyển trạng thái máy sang `installed` thủ công (hữu ích khi máy đích bị tường lửa chặn đường truyền gọi phone-home).

#### `POST /api/machines/installed`
Endpoint công khai nhận callback phone-home từ lệnh `late-commands` của cloud-init khi quá trình cài đặt kết thúc.
- **Request Body**:
  ```json
  {
    "mac": "52:54:00:12:34:56"
  }
  ```

---

## 3. Nhóm API Thiết Lập & Trạng Thái Hệ Thống

#### `GET /api/settings`
Lấy toàn bộ cấu hình máy chủ (Base URL, danh mục OS images, SSH keys mặc định, APT mirror mặc định).

#### `PUT /api/settings`
Cập nhật cấu hình máy chủ (bao gồm `apt_mirror_default`).

#### `POST /api/settings/test-apt-mirror`
Kiểm tra khả năng kết nối và đo độ trễ tới URL APT mirror mục tiêu.
- **Request Body**:
  ```json
  {
    "url": "http://vn.archive.ubuntu.com/ubuntu/"
  }
  ```
- **Response mẫu**:
  ```json
  {
    "ok": true,
    "status_code": 200,
    "latency_ms": 483,
    "message": "Mirror reachable (483ms, HTTP 200)"
  }
  ```

#### `POST /api/assets/fetch`
Kích hoạt tiến trình tải ISO từ internet, trích xuất kernel/initrd và lưu cache cho một bản phân phối OS.

#### `GET /api/system/info`
Trả về số liệu runtime của máy chủ:
```json
{
  "version": "0.1.0",
  "memory_used_mb": 42.5,
  "uptime_seconds": 86400,
  "dev_mode": false
}
```

#### `GET /healthz`
Trả về mã `200 OK` phục vụ health check cho container hoặc dịch vụ giám sát.

---

## 4. Dịch Vụ Boot & Cài Đặt Qua Mạng

#### `GET /boot.ipxe?mac=:mac`
Sinh kịch bản iPXE tương ứng với trạng thái vòng đời hiện tại của máy có địa chỉ MAC được chỉ định.

#### `GET /os/:os_name/:version/:mac/user-data`
Sinh file cấu hình autoinstall cloud-init cho Ubuntu chứa phân vùng ổ cứng, mạng và `late-commands`.

#### `GET /assets/:os_name/:version/:file`
Cung cấp file nhị phân kernel (`vmlinuz`) và initrd đã lưu cache.

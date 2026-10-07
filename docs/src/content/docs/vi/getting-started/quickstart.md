---
title: Cài Đặt Nhanh
description: Thiết lập môi trường phát triển và chạy iPXE ZTP trên máy cục bộ.
---

Tài liệu này hướng dẫn bạn cài đặt và chạy môi trường phát triển iPXE ZTP chỉ với vài thao tác đơn giản.

## Yêu Cầu Tiên Quyết

Trước khi bắt đầu, hãy đảm bảo máy tính của bạn đã cài đặt:

- **[mise](https://mise.jdx.dev/)** (công cụ quản lý môi trường được khuyến nghị) hoặc:
  - Trình biên dịch **V** (phiên bản `0.5.2` trở lên)
  - **Node.js** (v20+ hoặc v22 LTS) cùng **npm**
  - **SQLite 3**
  - **curl** và **lsof**

## 1. Clone Mã Nguồn

```bash
git clone https://github.com/001123/lab-v-ipxe.git
cd lab-v-ipxe
```

Nếu bạn sử dụng `mise`, hãy cấp quyền tin cậy file cấu hình một lần duy nhất:

```bash
mise trust
```

## 2. Cài Đặt Dependencies Cho Frontend

```bash
cd web && npm install && cd ..
```

## 3. Khởi Chạy Bộ Môi Trường Dev

Khởi động đồng thời cả backend V và frontend Next.js chỉ với một lệnh qua `mise`:

```bash
mise run dev
```

Tác vụ này sẽ tự động:
1. Quét và dừng các tiến trình còn sót lại từ lần chạy trước trên cổng `:4793` và `:4794`.
2. Khởi động backend V tại `http://localhost:4793`.
3. Chờ endpoint kiểm tra sức khỏe `/healthz` phản hồi thành công.
4. Bật server dev của Next.js tại `http://localhost:4794` với cơ chế proxy API tự động.

## 4. Truy Cập Giao Diện Quản Trị Web

Mở trình duyệt web và truy cập:

- **Địa chỉ**: [http://localhost:4794](http://localhost:4794)
- **Tài khoản**: `admin@ipxe.local`
- **Mật khẩu**: `admin@pwd`

## 5. Đóng Gói Thành File Nhị Phân Production (Single Binary)

Để biên dịch toàn bộ hệ thống kèm giao diện web thành một file nhị phân độc lập duy nhất:

```bash
# 1. Build xuất file tĩnh từ Next.js
cd web && npm run build && cd ..

# 2. Sinh mã nguồn V nhúng tài nguyên tĩnh
v run scripts/gen_embed.vsh

# 3. Biên dịch binary chế độ tối ưu production
v -prod -o bin/lab-v-ipxe .
```

Sau khi hoàn tất, bạn có thể thực thi trực tiếp file nhị phân mà không cần cài thêm Node.js hay V:

```bash
./bin/lab-v-ipxe
```

Ở chế độ production, file nhị phân sẽ phục vụ cả web UI lẫn API trên cổng mặc định `4793`.

## 6. Chạy Trang Tài Liệu (Docs Dev Server)

Để xem tài liệu nội bộ trên máy của bạn:

```bash
mise run docs:dev
```

Mở trình duyệt tại [http://localhost:4795](http://localhost:4795) để tra cứu tài liệu.

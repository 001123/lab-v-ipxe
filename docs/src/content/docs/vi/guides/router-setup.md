---
title: Cấu Hình Router & DHCP
description: Hướng dẫn cấu hình OpenWrt, dnsmasq và ISC DHCP để chainload iPXE qua mạng.
---

Để kích hoạt tính năng tự động hóa Zero Touch Provisioning, máy chủ DHCP trong mạng nội bộ cần cung cấp các chỉ dẫn boot mạng:
1. Gửi file thực thi iPXE ban đầu (`ipxe.efi` hoặc `undionly.kpxe`) qua TFTP/HTTP cho card mạng chưa có iPXE.
2. Khi bootloader iPXE khởi chạy và gửi yêu cầu DHCP lần thứ hai kèm cờ user class `iPXE`, router sẽ chuyển tiếp máy tới địa chỉ của **iPXE ZTP**.

---

## 1. OpenWrt (dnsmasq)

Thêm cấu hình sau vào `/etc/dnsmasq.conf` hoặc giao diện LuCI trên router chạy OpenWrt:

### `/etc/dnsmasq.conf`

```ini
# Bật máy chủ TFTP nội bộ
enable-tftp
tftp-root=/srv/tftp

# Nhận diện kiến trúc CPU của máy client
dhcp-match=set:bios,option:client-arch,0
dhcp-match=set:efi-x86_64,option:client-arch,7
dhcp-match=set:efi-x86_64,option:client-arch,9
dhcp-match=set:efi-arm64,option:client-arch,11

# Nhận diện máy đã nạp iPXE thành công
dhcp-userclass=set:ipxe,iPXE

# Nếu đã nạp iPXE, trỏ sang máy chủ iPXE ZTP
dhcp-boot=tag:ipxe,http://192.168.1.10:4793/boot.ipxe?mac=${net0/mac}

# Nếu chưa, gửi file iPXE tương ứng với kiến trúc
dhcp-boot=tag:bios,undionly.kpxe,,192.168.1.10
dhcp-boot=tag:efi-x86_64,ipxe.efi,,192.168.1.10
dhcp-boot=tag:efi-arm64,ipxe-arm64.efi,,192.168.1.10
```

*Thay thế `192.168.1.10` bằng địa chỉ IP thực tế của máy chủ iPXE ZTP.*

Khởi động lại dịch vụ dnsmasq trên OpenWrt:
```bash
/etc/init.d/dnsmasq restart
```

---

## 2. Máy Chủ ISC DHCP (`dhcpd.conf`)

Dành cho hệ thống Linux sử dụng daemon `isc-dhcp-server`:

```text
subnet 192.168.1.0 netmask 255.255.255.0 {
    range 192.168.1.100 192.168.1.200;
    option routers 192.168.1.1;
    option domain-name-servers 1.1.1.1, 8.8.8.8;

    next-server 192.168.1.10;

    if exists user-class and option user-class = "iPXE" {
        filename "http://192.168.1.10:4793/boot.ipxe?mac=${net0/mac}";
    } elsif option architecture-type = 00:07 or option architecture-type = 00:09 {
        filename "ipxe.efi";
    } else {
        filename "undionly.kpxe";
    }
}
```

---

## 3. OPNsense / pfSense

1. Mở giao diện quản trị: **Services → DHCP Server → [Interface mạng LAN của bạn]**.
2. Cuộn xuống phần **Network Booting**.
3. Tích chọn **Enable Network Booting**.
4. Điền **Next Server** là IP máy chủ iPXE (ví dụ `192.168.1.10`).
5. Tại ô **Default BIOS file name**, nhập `undionly.kpxe`.
6. Tại ô **UEFI 64 bit file name**, nhập `ipxe.efi`.

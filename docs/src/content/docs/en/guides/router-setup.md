---
title: Router & DHCP Configuration
description: How to configure OpenWrt, dnsmasq, and ISC DHCP for iPXE network chainloading.
---

To enable Zero Touch Provisioning, your local DHCP server must hand out PXE boot instructions:
1. Provide the initial iPXE binary (`ipxe.efi` or `undionly.kpxe`) via TFTP/HTTP to uninitialized network cards.
2. When the iPXE bootloader executes and sends a second DHCP request containing user class `iPXE`, instruct it to chainload the **iPXE ZTP** server endpoint.

---

## 1. OpenWrt (dnsmasq)

Add the following configuration to `/etc/dnsmasq.conf` or `/etc/config/dhcp` on your OpenWrt router:

### `/etc/dnsmasq.conf`

```ini
# Enable TFTP server
enable-tftp
tftp-root=/srv/tftp

# Detect client architecture
dhcp-match=set:bios,option:client-arch,0
dhcp-match=set:efi-x86_64,option:client-arch,7
dhcp-match=set:efi-x86_64,option:client-arch,9
dhcp-match=set:efi-arm64,option:client-arch,11

# Detect if the client is already running iPXE
dhcp-userclass=set:ipxe,iPXE

# If already iPXE, hand off to the iPXE ZTP server
dhcp-boot=tag:ipxe,http://192.168.1.10:4793/boot.ipxe?mac=${net0/mac}

# Otherwise, send the matching iPXE binary
dhcp-boot=tag:bios,undionly.kpxe,,192.168.1.10
dhcp-boot=tag:efi-x86_64,ipxe.efi,,192.168.1.10
dhcp-boot=tag:efi-arm64,ipxe-arm64.efi,,192.168.1.10
```

*Replace `192.168.1.10` with the actual IP address of your iPXE ZTP server.*

Restart dnsmasq on OpenWrt:
```bash
/etc/init.d/dnsmasq restart
```

---

## 2. ISC DHCP Server (`dhcpd.conf`)

For standard Linux servers running `isc-dhcp-server`:

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

1. Navigate to **Services → DHCP Server → [Your LAN Interface]**.
2. Scroll down to **Network Booting**.
3. Check **Enable Network Booting**.
4. Set **Next Server** to your server IP (e.g. `192.168.1.10`).
5. In **Default BIOS file name**, set `undionly.kpxe`.
6. In **UEFI 64 bit file name**, set `ipxe.efi`.

---
title: Storage Layouts & Boot Modes
description: Understanding NFS network boot, ISO caching mechanisms, and storage partition presets.
---

**iPXE ZTP** optimizes both the network boot speed and the physical disk partition architecture for target machines.

## Boot Architecture: NFS vs HTTP

Network booting modern Linux distributions requires transferring the kernel (`vmlinuz`), the initial ramdisk (`initrd`), and mounting the root filesystem (`casper/filesystem.squashfs`).

### NFS Boot Mode (Default)
In homelab and enterprise LANs, **NFS (Network File System)** provides exceptional throughput compared to HTTP stream unpacking:
- iPXE downloads the ~100MB kernel and initrd directly via NFS.
- The Linux kernel mounts the live root filesystem over NFS via kernel parameters:
  `root=/dev/nfs nfsroot=${NFS_SERVER}:${NFS_PATH} ip=dhcp boot=casper`
- Installation takes under 2–3 minutes over a Gigabit LAN.

### Smart ISO Caching
Instead of requiring manual extraction or keeping multi-gigabyte ISOs permanently on disk:
1. When a new Ubuntu point release (e.g. `24.04.5` or `26.04.1`) is first requested, the server downloads the official Canonical ISO.
2. It extracts only the essential boot files: `casper/vmlinuz` and `casper/initrd`.
3. The extracted files (~100MB total) are stored in the local cache directory (`<data>/cache/`).
4. The multi-gigabyte ISO is immediately purged to save disk space.

---

## Storage Layout Presets

During machine approval or editing, administrators can assign one of three distinct disk layout templates:

### 1. Direct (ext4, Default)
A lean, standard layout ideal for general-purpose servers and virtual machines:
- **Partition 1**: 1 GB EFI System Partition (`/boot/efi`, FAT32).
- **Partition 2**: Remaining disk space formatted as `ext4` mounted at `/`.
- **Advantages**: Minimal overhead, maximum compatibility, zero extra kernel module requirements.

### 2. ZFS on Root
Engineered for enterprise reliability, atomic snapshots, and data integrity:
- **Pool layout**: ZFS root pool (`rpool/ROOT/ubuntu`).
- **Memory tuning**: ZFS ARC (Adaptive Replacement Cache) can consume all available RAM if unconstrained. **iPXE ZTP** generates custom `/etc/modprobe.d/zfs.conf` parameters:
  ```ini
  # Automatically calculated based on target system RAM
  options zfs zfs_arc_max=2147483648
  ```
  This prevents out-of-memory lockups on resource-constrained homelab nodes and mini-PCs.

### 3. LVM (Logical Volume Manager)
Best suited for corporate environments requiring dynamic volume resizing:
- **Volume Group**: `vg_ubuntu`
- **Logical Volumes**:
  - `lv_root`: Formatted as ext4 mounted at `/`.
  - `lv_swap`: Swap space sized dynamically based on physical RAM.
- **Advantages**: Online partition resizing, LVM thin provisioning support.

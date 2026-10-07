---
title: Machine Management & Web Console
description: Managing servers, reviewing pending discoveries, and orchestrating installations from the Web UI.
---

The **iPXE ZTP** Web Console provides an intuitive, real-time command center for monitoring and managing your fleet of physical servers and virtual machines.

## Dashboard Overview

Upon logging in with your administrator credentials (`admin@ipxe.local`), you are greeted with:
- **Status Cards**: Real-time counter of total machines, pending approvals, active installations, and installed nodes.
- **Server Health**: Memory usage, CPU load, and uptime of the iPXE ZTP server.
- **Machine Table**: Fast, searchable inventory of all known MAC addresses.

---

## 1. Approving a Pending Machine

When an unknown physical server powers on and boots via iPXE, it automatically registers with status **`pending`**.

1. In the **Machines** table, look for the highlighted `Pending` badge.
2. Click the **Approve** button or click the machine row to open the configuration drawer.
3. Configure the machine parameters:
   - **Hostname**: Target FQDN (e.g. `k8s-worker-01`).
   - **IP Allocation**: Choose **DHCP** or enter a **Static IP / Netmask / Gateway / DNS**.
   - **Operating System**: Select the target Ubuntu release (e.g. `24.04.5`).
   - **Storage Layout**: Choose `direct` (ext4), `zfs` root, or `lvm`.
   - **SSH Public Key**: Paste your authorized public key for passwordless root SSH access.
4. Click **Confirm Approval**.

The machine status changes to `approved`. Within 10 seconds, the target machine will detect the approval, begin downloading the kernel/initrd, and proceed with automated installation.

---

## 2. Monitoring Active Installations

While Subiquity is formatting disks and installing packages, the machine status is shown as **`installing`**.
- The installer streams status updates to the system logs.
- Once Subiquity finishes, the cloud-init `late-commands` automatically execute a phone-home HTTP POST request to `/api/machines/installed`.
- The status turns green as **`installed`**.

> **Manual Override**: If an isolated VLAN prevents the newly installed machine from reaching the server's HTTP port during post-install, an administrator can simply click **Mark installed** in the web console to complete the transition manually.

---

## 3. Triggering Reinstallation

To wipe and re-provision an existing machine from scratch:
1. Locate the machine in the table.
2. Open the actions menu (`...`) and click **Reinstall**.
3. The server resets the status to `approved`.
4. Reboot the target machine (via IPMI, Wake-on-LAN, or physically). On boot, iPXE will immediately begin re-installing the OS.

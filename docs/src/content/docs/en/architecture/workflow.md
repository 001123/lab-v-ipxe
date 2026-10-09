---
title: Machine Lifecycle & Workflow
description: In-depth explanation of the Zero Touch Provisioning lifecycle and state transitions.
---

The core strength of **iPXE ZTP** is its autonomous machine lifecycle management. Machines transition through clear, auditable states from initial power-on to production readiness.

## Lifecycle State Machine

```
                   [ Machine Powers On ]
                            │
                            ▼
                   iPXE DHCP Chainload
                            │
               ┌────────────┴────────────┐
               │ MAC exists in Database? │
               └────────────┬────────────┘
                     No     │     Yes
         ┌──────────────────┘     └──────────────────┐
         ▼                                           ▼
   [ PENDING ]                               Check Machine Status
  (Polls /boot.ipxe                                  │
    every 10s)                                       ├─ status == 'approved'
         │                                           │       │
         │ Administrator                             │       ▼
         │ clicks "Approve"                          │   [ INSTALLING ]
         ▼                                           │  (Serves NFS kernel +
   [ APPROVED ] ◄────────────────────────────────────┘   cloud-init user-data)
         │                                                   │
         │ Next poll triggers boot                           │ OS install completes
         ▼                                                   │ (late-command phone-home)
   [ INSTALLING ]                                            ▼
         │                                             [ INSTALLED ]
         └───────────────────────────────────────────► (Reboot → sanboot
                                                        from local disk)
```

## Detailed State Breakdown

### 1. Discovery (`pending`)
- When a target physical server or virtual machine turns on, its network card (NIC) triggers a PXE request.
- The local DHCP server (e.g. OpenWrt `dnsmasq`) instructs the machine to load the iPXE bootloader.
- iPXE queries the application:
  ```bash
  chain http://<SERVER_IP>:4793/boot.ipxe?mac=${net0/mac}
  ```
- If the MAC address is unrecognized, the server creates a new machine entry in SQLite with status `pending` and returns a looping script:
  ```bash
  #!ipxe
  echo Machine ${mac} registered. Waiting for approval...
  sleep 10
  chain http://<SERVER_IP>:4793/boot.ipxe?mac=${mac}
  ```

### 2. Approval (`approved`)
- The administrator opens the Web Console and sees the machine highlighted in the pending queue.
- You can configure:
  - **Hostname** (e.g., `node-01.lab.local`)
  - **IP Address & Subnet** (static or DHCP)
  - **Operating System** (Ubuntu 24.04.5 or 26.04.1)
  - **Storage Layout** (`direct`, `zfs`, or `lvm`)
- Clicking **Approve** updates the status to `approved`.

### 3. Installation (`installing`)
- On the next 10-second polling cycle, the server detects the `approved` status.
- It automatically changes the status to `installing` and outputs the boot payload:
  ```bash
  #!ipxe
  kernel nfs://${NFS_SERVER}/${NFS_EXPORT}/casper/vmlinuz ip=dhcp autoinstall ds=nocloud-net;s=http://${SERVER_IP}:4793/autoinstall/${mac}/
  initrd nfs://${NFS_SERVER}/${NFS_EXPORT}/casper/initrd
  boot
  ```
- Ubuntu Subiquity reads the autoinstall configuration generated dynamically from `/autoinstall/:mac/user-data`.

### 4. Completion & Phone-Home (`installed`)
- Upon completing installation, cloud-init executes the configured `late-commands`:
  ```bash
  curl -fsS -X POST http://${SERVER_IP}:4793/api/machines/installed \
    -H "Content-Type: application/json" \
    -d '{"mac": "..."}'
  ```
- The server marks the machine as `installed`.
- The machine reboots. On all subsequent network boot attempts, `/boot.ipxe` returns:
  ```bash
  #!ipxe
  sanboot --no-describe --drive 0x80
  ```
  This immediately delegates control to the local hard drive, preventing infinite reinstall loops.

### 5. Ansible-Ready Out-of-the-Box (Day-1 Integration)
A significant advantage of **lab-v-ipxe** over conventional PXE solutions is its seamless **Day-0 to Day-1 automation**:
- **Automatic Passwordless Sudo**: `/etc/sudoers.d/90-lab-nopasswd` (`ubuntu ALL=(ALL) NOPASSWD:ALL`) is provisioned via `late-commands`. This permanently fixes compatibility issues with `sudo-rs` (shipped in Ubuntu 24.04/26.04), whose password prompt format causes standard Ansible password-based `become` prompts to hang or time out.
- **SSH Key & Python 3**: Your SSH public key is pre-injected into `~/.ssh/authorized_keys`, and Python 3 is verified in PATH.
- **Optimized APT Repos**: Sources are configured to point directly to your preferred mirror or LAN caching proxy.
- **Instant verification**:
  ```bash
  # Check connectivity and discover facts
  ansible all -i '<machine-ip>,' -m ping -u ubuntu

  # Sudo privilege escalation without password prompts
  ansible all -i '<machine-ip>,' -m command -a 'whoami' -u ubuntu -b
  ```
The instant a node switches to `installed` on the Web Console, automated CI/CD runners or Ansible playbooks can immediately take over (e.g. bootstrapping K3s clusters, configuring Docker, or provisioning Tailscale) with zero manual setup.

### 6. Reinstallation
If you ever want to re-provision a node, click the **Reinstall** button in the Web Console. The machine status flips back to `approved` and will automatically re-install on its next boot.

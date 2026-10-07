module ubuntu

import core

// nfs_install_script renders the NFS-mode iPXE script. The kernel cmdline is
// the one proven in the lab: initrd= must NOT appear on the kernel line
// (UEFI EFI_LOAD_FILE2 conflict), ramdisk_size is required for the 24.04 live
// initrd, cloud-config-url=/dev/null stops subiquity's metadata probing.
pub fn nfs_install_script(req core.BootRequest) string {
	assets_base := '${req.base_url}/assets/ubuntu/${req.os_version}'
	os_base := '${req.base_url}/os/ubuntu/${req.os_version}/${req.mac}'
	cmdline := 'root=/dev/ram0 ramdisk_size=3500000 boot=casper netboot=nfs nfsroot=${req.nfs_root} ip=dhcp autoinstall ds=nocloud-net;s=${os_base}/ cloud-config-url=/dev/null --- quiet'
	return '#!ipxe\n' +
		'echo lab-v-ipxe: installing ${req.hostname} (ubuntu ${req.os_version}, NFS mode)\n' +
		'kernel ${assets_base}/vmlinuz ${cmdline}\n' + 'initrd ${assets_base}/initrd\n' + 'boot\n'
}

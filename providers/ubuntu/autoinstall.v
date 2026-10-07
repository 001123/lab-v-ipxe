module ubuntu

import core

// $6$ sha512-crypt hash of the default password "ubuntu" (salt
// ipxeDefaultSalt0), used when a machine has no custom password configured.
pub const fallback_password_hash = '$6$ipxeDefaultSalt0$DlJ9SNa0PH5xkOyTIl3yKt/D0oXnG1B0A9ocqMltiua1I1wmvXOkMiaHXJ3jG.7EekliizetXlkqyhXcu4wfS.'

// ZFS ARC cap/floor for low-RAM machines (bytes).
const zfs_arc_max = 536870912
const zfs_arc_min = 134217728

// render_user_data builds the subiquity autoinstall user-data for one machine.
pub fn render_user_data(req core.BootRequest) string {
	password := if req.password_hash != '' { req.password_hash } else { fallback_password_hash }
	mut lines := []string{}
	lines << '#cloud-config'
	lines << 'autoinstall:'
	lines << '  version: 1'
	lines << '  interactive-sections: []'
	lines << '  refresh-installer:'
	lines << '    update: false'
	lines << '  keyboard:'
	lines << '    layout: us'
	lines << '  locale: en_US.UTF-8'
	lines << '  identity:'
	lines << '    hostname: ${req.hostname}'
	lines << '    username: ${req.username}'
	lines << "    password: '${password}'"
	lines << '  ssh:'
	lines << '    install-server: true'
	lines << '    allow-pw: true'
	if req.ssh_keys != '' {
		lines << '    authorized-keys:'
		for key in req.ssh_keys.split_into_lines() {
			k := key.trim_space()
			if k != '' {
				lines << "      - '${k}'"
			}
		}
	}
	lines << '  storage:'
	lines << '    layout:'
	lines << '      name: ${req.storage_layout.str()}'
	if req.storage_disk != '' {
		lines << '      match:'
		lines << "        path: '${req.storage_disk}'"
	}
	lines << '  packages:'
	lines << '    - qemu-guest-agent'
	lines << '    - curl'
	lines << '  late-commands:'
	if req.storage_layout == .zfs {
		lines << '    - curtin in-target -- sh -c "printf \'options zfs zfs_arc_max=${zfs_arc_max} zfs_arc_min=${zfs_arc_min}\\n\' > /etc/modprobe.d/zfs.conf"'
		lines << '    - curtin in-target -- update-initramfs -u'
	}
	lines << '    - curtin in-target -- systemctl enable qemu-guest-agent'
	lines << '    - curtin in-target -- curl -sS -X POST -d "mac=${req.mac}&hostname=${req.hostname}" ${req.base_url}/api/machines/installed || true'
	return lines.join('\n') + '\n'
}

// render_meta_data builds the NoCloud meta-data. instance-id changes on every
// reinstall so cloud-init re-runs the autoinstall.
pub fn render_meta_data(req core.BootRequest) string {
	return 'instance-id: i-${req.mac_key}-${req.install_count}\nlocal-hostname: ${req.hostname}\n'
}

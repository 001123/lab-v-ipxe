module ubuntu

import internal.boot
import json2
import net.urllib

// $6$ sha512-crypt hash of the default password "ubuntu" (salt
// ipxeDefaultSalt0), used when a machine has no custom password configured.
pub const fallback_password_hash = '$6$ipxeDefaultSalt0$DlJ9SNa0PH5xkOyTIl3yKt/D0oXnG1B0A9ocqMltiua1I1wmvXOkMiaHXJ3jG.7EekliizetXlkqyhXcu4wfS.'

// ZFS ARC cap/floor for low-RAM machines (bytes).
const zfs_arc_max = 536870912 // 512 MiB (512 * 1024 * 1024 bytes)
const zfs_arc_min = 134217728 // 128 MiB (128 * 1024 * 1024 bytes)

// yaml_str renders a scalar as a double-quoted YAML string using the JSON
// encoder (YAML 1.2 is a superset of JSON): stored values cannot inject extra
// keys or break the document even if they bypassed input validation.
fn yaml_str(s string) string {
	return json2.encode(s, escape_unicode: true, time_as_unix: true)
}

// sh_sq escapes a value interpolated inside the single-quoted shell fragment
// of a late-command: newlines are folded so the YAML line cannot break, and
// ' becomes '\''.
fn sh_sq(s string) string {
	return s.replace('\r', ' ').replace('\n', ' ').replace("'", "'\\''")
}

// render_user_data builds the subiquity autoinstall user-data for one machine.
pub fn render_user_data(req boot.BootRequest) string {
	password := if req.password_hash != '' { req.password_hash } else { fallback_password_hash }
	mut lines := []string{}
	lines << '#cloud-config'
	lines << 'autoinstall:'
	lines << '  version: 1'
	lines << '  interactive-sections: []'
	lines << '  refresh-installer:'
	lines << '    update: false'
	if req.keep_ipxe_first {
		lines << '  early-commands:'
		lines << '    - sh -c "test -d /sys/firmware/efi/efivars && efibootmgr | grep \'^BootCurrent:\' | cut -d\' \' -f2 > /run/ipxe_boot_current || true"'
	}
	lines << '  keyboard:'
	lines << '    layout: us'
	lines << '  locale: en_US.UTF-8'
	lines << '  identity:'
	lines << '    hostname: ${yaml_str(req.hostname)}'
	lines << '    username: ${yaml_str(req.username)}'
	lines << '    password: ${yaml_str(password)}'
	lines << '  ssh:'
	lines << '    install-server: true'
	lines << '    allow-pw: true'
	if req.ssh_keys != '' {
		lines << '    authorized-keys:'
		for key in req.ssh_keys.split_into_lines() {
			k := key.trim_space()
			if k != '' {
				lines << '      - ${yaml_str(k)}'
			}
		}
	}
	lines << '  storage:'
	lines << '    layout:'
	lines << '      name: ${req.storage_layout.str()}'
	if req.storage_disk != '' {
		lines << '      match:'
		lines << '        path: ${yaml_str(req.storage_disk)}'
	}
	lines << '  packages:'
	lines << '    - qemu-guest-agent'
	lines << '    - curl'
	lines << '  late-commands:'
	if req.storage_layout == .zfs {
		lines << '    - curtin in-target -- sh -c "printf \'options zfs zfs_arc_max=${zfs_arc_max} zfs_arc_min=${zfs_arc_min}\\n\' > /etc/modprobe.d/zfs.conf"'
		lines << '    - curtin in-target -- update-initramfs -u'
	}
	// Ansible-ready: passwordless sudo for the admin user. Ubuntu 26.04 ships
	// sudo-rs, whose auth prompt breaks Ansible's password-based become.
	lines << '    - curtin in-target -- sh -c "printf \'${sh_sq(req.username)} ALL=(ALL) NOPASSWD:ALL\\n\' > /etc/sudoers.d/90-lab-nopasswd && chmod 440 /etc/sudoers.d/90-lab-nopasswd"'
	lines << '    - curtin in-target -- systemctl enable qemu-guest-agent'
	if req.keep_ipxe_first {
		lines << '    - sh -c \'if [ -d /sys/firmware/efi/efivars ] && command -v efibootmgr >/dev/null 2>&1; then pxe=\$(cat /run/ipxe_boot_current 2>/dev/null | tr -d " \\r\\n"); [ -z "\$pxe" ] && pxe=\$(efibootmgr | grep -iE "pxe|ipv4|ipxe|network|ethernet" | head -n1 | sed -n "s/^Boot\\([0-9A-Fa-f]\\{4\\}\\).*/\\1/p"); u=\$(efibootmgr | grep -i "ubuntu" | head -n1 | sed -n "s/^Boot\\([0-9A-Fa-f]\\{4\\}\\).*/\\1/p"); cur=\$(efibootmgr | grep "^BootOrder:" | cut -d" " -f2 | tr -d " \\r\\n"); if [ -n "\$pxe" ]; then ord="\$pxe"; [ -n "\$u" ] && [ "\$u" != "\$pxe" ] && ord="\$ord,\$u"; IFS=","; for x in \$cur; do case ",\$ord," in *",\$x,"*) ;; *) ord="\$ord,\$x" ;; esac; done; unset IFS; efibootmgr -o "\$ord" || true; fi; fi\''
	}
	lines << '    - curtin in-target -- curl -sS -X POST -d "mac=${req.mac}&hostname=${urllib.query_escape(req.hostname)}" ${req.base_url}/api/machines/installed || true'
	return lines.join('\n') + '\n'
}

// render_meta_data builds the NoCloud meta-data. instance-id changes on every
// reinstall so cloud-init re-runs the autoinstall.
pub fn render_meta_data(req boot.BootRequest) string {
	return 'instance-id: i-${req.mac_key}-${req.install_count}\nlocal-hostname: ${yaml_str(req.hostname)}\n'
}

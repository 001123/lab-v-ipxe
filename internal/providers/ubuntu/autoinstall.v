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

// add_late_cmd appends a shell command safely encoded as a JSON/YAML string
// scalar using yaml_str so colons, newlines, or quotes never break YAML parsing.
fn add_late_cmd(mut lines []string, cmd string) {
	lines << '    - ${yaml_str(cmd)}'
}

pub const default_apt_mirror = 'http://archive.ubuntu.com/ubuntu/'

// resolve_apt_mirror returns the configured mirror or falls back to Canonical default.
pub fn resolve_apt_mirror(raw string) string {
	v := raw.trim_space()
	if v == '' {
		return default_apt_mirror
	}
	return if v.ends_with('/') { v } else { '${v}/' }
}

// render_user_data builds the subiquity autoinstall user-data for one machine.
pub fn render_user_data(req boot.BootRequest) string {
	password := if req.password_hash != '' { req.password_hash } else { fallback_password_hash }
	mirror := resolve_apt_mirror(req.apt_mirror)
	mut lines := []string{}
	lines << '#cloud-config'
	lines << 'autoinstall:'
	lines << '  version: 1'
	lines << '  interactive-sections: []'
	lines << '  refresh-installer:'
	lines << '    update: false'
	lines << '  apt:'
	lines << '    geoip: false'
	lines << '    fallback: offline-install'
	lines << '    primary:'
	lines << '      - arches: [default]'
	lines << '        uri: ${mirror}'
	lines << '    disable_suites: [security, updates, backports]'
	lines << '    conf: |'
	lines << '      Acquire::ForceIPv4 "true";'
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
	lines << '  late-commands:'
	if req.storage_layout == .zfs {
		add_late_cmd(mut lines, 'curtin in-target -- sh -c "printf \'options zfs zfs_arc_max=${zfs_arc_max} zfs_arc_min=${zfs_arc_min}\\n\' > /etc/modprobe.d/zfs.conf"')
		add_late_cmd(mut lines, 'curtin in-target -- update-initramfs -u')
	}
	// Ansible-ready: passwordless sudo for the admin user. Ubuntu 26.04 ships
	// sudo-rs, whose auth prompt breaks Ansible's password-based become.
	add_late_cmd(mut lines, 'curtin in-target -- sh -c "printf \'${sh_sq(req.username)} ALL=(ALL) NOPASSWD:ALL\\n\' > /etc/sudoers.d/90-lab-nopasswd && chmod 440 /etc/sudoers.d/90-lab-nopasswd"')
	add_late_cmd(mut lines, 'curtin in-target -- systemctl enable qemu-guest-agent 2>/dev/null || true')
	// Restore full repositories (security, updates, backports) after install
	// using the configured mirror so subsequent apt updates in the OS are immediate.
	add_late_cmd(mut lines, 'curtin in-target -- sh -c \'rel=\$(. /etc/os-release && echo "\$UBUNTU_CODENAME"); if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then printf "Types: deb\\nURIs: ${mirror}\\nSuites: %s %s-updates %s-backports %s-security\\nComponents: main restricted universe multiverse\\nSigned-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\\n" "\$rel" "\$rel" "\$rel" "\$rel" > /etc/apt/sources.list.d/ubuntu.sources; elif [ -f /etc/apt/sources.list ]; then printf "deb ${mirror} %s main restricted universe multiverse\\ndeb ${mirror} %s-updates main restricted universe multiverse\\ndeb ${mirror} %s-backports main restricted universe multiverse\\ndeb ${mirror} %s-security main restricted universe multiverse\\n" "\$rel" "\$rel" "\$rel" "\$rel" > /etc/apt/sources.list; fi\'')
	if req.keep_ipxe_first {
		add_late_cmd(mut lines, 'curtin in-target -- sh -c \'if [ -d /sys/firmware/efi/efivars ] && command -v efibootmgr >/dev/null 2>&1; then pxe=\$(efibootmgr | grep "^BootCurrent:" | cut -d" " -f2 | tr -d " \\r\\n"); if [ -n "\$pxe" ] && ! efibootmgr | grep -E "^Boot\$pxe\\*?" | grep -qiE "pxe|ipv4|ipxe|network|ethernet"; then pxe=""; fi; [ -z "\$pxe" ] && pxe=\$(efibootmgr | grep -iE "pxe|ipv4|ipxe|network|ethernet" | head -n1 | sed -n "s/^Boot\\([0-9A-Fa-f]\\{4\\}\\).*/\\1/p"); cur=\$(efibootmgr | grep "^BootOrder:" | cut -d" " -f2 | tr -d " \\r\\n"); if [ -n "\$pxe" ] && [ -n "\$cur" ]; then ord="\$pxe"; IFS=","; for x in \$cur; do [ "\$x" != "\$pxe" ] && ord="\$ord,\$x"; done; unset IFS; efibootmgr -o "\$ord" || true; fi; fi\'')
	}
	add_late_cmd(mut lines, 'curtin in-target -- curl -sS -X POST -d "mac=${req.mac}&hostname=${urllib.query_escape(req.hostname)}" ${req.base_url}/api/machines/installed || true')
	return lines.join('\n') + '\n'
}

// render_meta_data builds the NoCloud meta-data. instance-id changes on every
// reinstall so cloud-init re-runs the autoinstall.
pub fn render_meta_data(req boot.BootRequest) string {
	return 'instance-id: i-${req.mac_key}-${req.install_count}\nlocal-hostname: ${yaml_str(req.hostname)}\n'
}

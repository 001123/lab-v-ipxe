module ubuntu

import core
import os
import sha512crypt

fn sample_req() core.BootRequest {
	return core.BootRequest{
		base_url:       'http://192.168.250.10:8080'
		mac:            'BC:24:11:00:24:99'
		mac_key:        'bc2411002499'
		hostname:       'vm-test'
		username:       'timi'
		password_hash:  ''
		ssh_keys:       'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleKey timi@workstation\nssh-rsa AAAAB3Nza example2'
		nfs_root:       '192.168.250.4:/srv/nfs/ubuntu-24.04'
		os_name:        'ubuntu'
		os_version:     '24.04'
		arch:           'amd64'
		storage_layout: .zfs
		install_count:  0
		boot_mode:      .nfs
	}
}

fn test_nfs_install_script() {
	u := new(new_assets('/nonexistent-cache', '', '', false))
	s := u.install_script(sample_req())!
	assert s.starts_with('#!ipxe')
	assert s.contains('kernel http://192.168.250.10:8080/assets/ubuntu/24.04/vmlinuz')
	assert s.contains('root=/dev/ram0 ramdisk_size=3500000 boot=casper')
	assert s.contains('netboot=nfs nfsroot=192.168.250.4:/srv/nfs/ubuntu-24.04')
	assert s.contains('ip=dhcp autoinstall')
	assert s.contains('ds=nocloud-net;s=http://192.168.250.10:8080/os/ubuntu/24.04/BC:24:11:00:24:99/')
	assert s.contains('cloud-config-url=/dev/null')
	assert s.contains('initrd http://192.168.250.10:8080/assets/ubuntu/24.04/initrd')
	assert s.ends_with('boot\n')
	// the kernel line must not carry initrd=
	kernel_lines := s.split_into_lines().filter(it.starts_with('kernel'))
	assert kernel_lines.len == 1
	assert !kernel_lines[0].contains('initrd=')
}

fn test_http_mode_not_implemented() {
	u := new(new_assets('/nonexistent-cache', '', '', false))
	mut req := sample_req()
	req.boot_mode = .http
	u.install_script(req) or {
		assert err.msg().contains('not implemented')
		return
	}
	assert false, 'http mode must not be implemented in the MVP'
}

fn test_user_data_zfs_defaults() {
	ud := render_user_data(sample_req())
	assert ud.starts_with('#cloud-config\n')
	assert ud.contains('    hostname: vm-test')
	assert ud.contains('    username: timi')
	assert ud.contains("    password: '${fallback_password_hash}'")
	assert ud.contains('      name: zfs')
	assert ud.contains("      - 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleKey timi@workstation'")
	assert ud.contains("      - 'ssh-rsa AAAAB3Nza example2'")
	assert ud.contains('zfs_arc_max=536870912')
	assert ud.contains('zfs_arc_min=134217728')
	assert ud.contains('update-initramfs -u')
	assert ud.contains('systemctl enable qemu-guest-agent')
	assert ud.contains('mac=BC:24:11:00:24:99&hostname=vm-test')
	assert ud.contains('http://192.168.250.10:8080/api/machines/installed')
}

fn test_user_data_custom_password_direct_layout_no_keys() {
	mut req := sample_req()
	req.password_hash = '$6$abc$def'
	req.storage_layout = .direct
	req.ssh_keys = ''
	ud := render_user_data(req)
	assert ud.contains("    password: '$6$abc$def'")
	assert ud.contains('      name: direct')
	assert !ud.contains('zfs_arc_max')
	assert !ud.contains('authorized-keys')
}

fn test_meta_data() {
	md := render_meta_data(sample_req())
	assert md.contains('instance-id: i-bc2411002499-0')
	assert md.contains('local-hostname: vm-test')
	mut req := sample_req()
	req.install_count = 3
	assert render_meta_data(req).contains('instance-id: i-bc2411002499-3')
}

fn test_fallback_hash_is_sha512crypt_of_ubuntu() {
	h := sha512crypt.hash('ubuntu', 'ipxeDefaultSalt0', 5000)
	assert h == fallback_password_hash
}

fn test_assets_ready_and_path_for() {
	am := new_assets('/nonexistent-cache', '', '', false)
	assert !am.ready('24.04')
	assert am.path_for('24.04', 'vmlinuz') == none
}

fn test_pick_latest_noble_iso() {
	html := '<a href="ubuntu-24.04.2-live-server-amd64.iso">x</a>\n<a href="ubuntu-24.04.3-live-server-amd64.iso">y</a>\n<a href="ubuntu-24.04-live-server-amd64.iso">z</a>\n<a href="ubuntu-24.04.10-live-server-amd64.iso">w</a>\n<a href="ubuntu-24.04.10-live-server-amd64.iso.torrent">t</a>'
	got := pick_latest_noble_iso(html) or { '' }
	assert got == 'ubuntu-24.04.10-live-server-amd64.iso'
	assert pick_latest_noble_iso('nothing here') == none
}

fn test_ensure_assets_ready_via_override() {
	tmp := os.join_path(os.vtmp_dir(), 'labvipxe_assets_${os.getpid()}')
	os.mkdir_all(tmp)!
	defer {
		os.rmdir_all(tmp) or {}
	}
	os.write_file(os.join_path(tmp, 'vmlinuz'), 'kernel-bytes')!
	os.write_file(os.join_path(tmp, 'initrd'), 'initrd-bytes')!
	am := new_assets(os.join_path(tmp, 'cache'), tmp, '', false)
	assert am.ready('24.04')
	am.ensure_assets('24.04')
	assert am.status_snapshot().phase == .ready
}

fn test_extractor_detection_lists_at_least_one_on_dev_machine() {
	tools := available_extractors()
	assert tools.len > 0
}

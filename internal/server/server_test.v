module server

import internal.config
import json2
import net.http
import os
import internal.store
import time
import veb

const test_port = 13081
const test_base = 'http://127.0.0.1:${test_port}'

fn h_auth(token string) http.Header {
	return http.new_header_from_map({
		http.CommonHeader.authorization: 'Bearer ${token}'
	})
}

fn h_json_auth(token string) http.Header {
	return http.new_header_from_map({
		http.CommonHeader.content_type:  'application/json'
		http.CommonHeader.authorization: 'Bearer ${token}'
	})
}

fn test_full_api_flow() {
	test_dir := os.join_path(os.vtmp_dir(), 'labvipxe_test_${os.getpid()}')
	os.mkdir_all(test_dir)!
	db_path := os.join_path(test_dir, 'test.db')
	// dummy kernel/initrd so the boot flow reaches the install branch; the env
	// var must be set before config.load() below
	assets_dir := os.join_path(test_dir, 'assets-override')
	os.mkdir_all(assets_dir)!
	os.write_file(os.join_path(assets_dir, 'vmlinuz'), 'kernel-bytes')!
	os.write_file(os.join_path(assets_dir, 'initrd'), 'initrd-bytes')!
	os.setenv('LAB_V_IPXE_UBUNTU_ASSETS_DIR', assets_dir, true)
	mut st := store.open(db_path)!
	st.migrate()!
	st.seed_admin('admin@ipxe.local', 'admin@pwd')!
	mut app := new_app(config.load(), st)
	spawn veb.run_at[App, Context](mut app, port: test_port, family: .ip)

	mut ready := false
	for _ in 0 .. 60 {
		if _ := http.fetch(url: '${test_base}/healthz') {
			ready = true
			break
		}
		time.sleep(100 * time.millisecond)
	}
	assert ready, 'server did not start'

	// unauthenticated access is rejected
	res := http.fetch(url: '${test_base}/api/machines')!
	assert res.status_code == 401

	// wrong password
	res2 := http.fetch(
		method: .post
		url:    '${test_base}/api/auth/login'
		data:   '{"email":"admin@ipxe.local","password":"nope"}'
	)!
	assert res2.status_code == 401

	// login
	res3 := http.fetch(
		method: .post
		url:    '${test_base}/api/auth/login'
		data:   '{"email":"admin@ipxe.local","password":"admin@pwd"}'
	)!
	assert res3.status_code == 200
	token := json2.decode[LoginRes](res3.body)!.token
	assert token != ''

	// settings: a fresh DB seeds the OS images catalog from config defaults
	res3b := http.fetch(url: '${test_base}/api/settings', header: h_auth(token))!
	assert res3b.status_code == 200
	seeded := json2.decode[SettingsRes](res3b.body)!
	assert seeded.os_images.len == 1
	assert seeded.os_images[0].os_name == 'ubuntu'
	assert seeded.os_images[0].version == config.default_ubuntu_version
	assert seeded.os_images[0].nfs_root == config.default_nfs_root
	assert seeded.os_images[0].is_default
	assert seeded.providers.len == 1
	assert seeded.providers[0].name == 'ubuntu'
	assert seeded.providers[0].display_name == 'Ubuntu'
	assert config.default_ubuntu_version in seeded.providers[0].versions
	assert seeded.assets.len == 1
	assert seeded.assets[0].os_name == 'ubuntu'
	assert seeded.assets[0].version == config.default_ubuntu_version
	assert seeded.assets[0].phase == 'ready'
	assert seeded.apt_mirror_default == ''

	// empty machine list
	res4 := http.fetch(url: '${test_base}/api/machines', header: h_auth(token))!
	assert res4.status_code == 200
	assert json2.decode[[]MachineDto](res4.body)!.len == 0

	// global ssh keys: set, echo back, and an empty payload keeps the current value
	res4b := http.fetch(
		method: .put
		url:    '${test_base}/api/settings'
		header: h_json_auth(token)
		data:   '{"ssh_keys_default":"ssh-ed25519 AAAA global@host"}'
	)!
	assert res4b.status_code == 200
	assert json2.decode[SettingsRes](res4b.body)!.ssh_keys_default == 'ssh-ed25519 AAAA global@host'
	res4c := http.fetch(url: '${test_base}/api/settings', header: h_auth(token))!
	assert json2.decode[SettingsRes](res4c.body)!.ssh_keys_default == 'ssh-ed25519 AAAA global@host'
	res4d := http.fetch(
		method: .put
		url:    '${test_base}/api/settings'
		header: h_json_auth(token)
		data:   '{"ssh_keys_default":""}'
	)!
	assert res4d.status_code == 200
	assert json2.decode[SettingsRes](res4d.body)!.ssh_keys_default == 'ssh-ed25519 AAAA global@host'

	// apt mirror: set, echo back, normalize trailing slash, clear with 'default'
	res4_apt := http.fetch(
		method: .put
		url:    '${test_base}/api/settings'
		header: h_json_auth(token)
		data:   '{"apt_mirror_default":"http://vn.archive.ubuntu.com/ubuntu"}'
	)!
	assert res4_apt.status_code == 200
	assert json2.decode[SettingsRes](res4_apt.body)!.apt_mirror_default == 'http://vn.archive.ubuntu.com/ubuntu/'
	res4_apt_reset := http.fetch(
		method: .put
		url:    '${test_base}/api/settings'
		header: h_json_auth(token)
		data:   '{"apt_mirror_default":"default"}'
	)!
	assert res4_apt_reset.status_code == 200
	assert json2.decode[SettingsRes](res4_apt_reset.body)!.apt_mirror_default == ''

	// invalid ssh keys / base_url are rejected at the boundary
	res4db := http.fetch(
		method: .put
		url:    '${test_base}/api/settings'
		header: h_json_auth(token)
		data:   '{"ssh_keys_default":"ssh-ed25519 AAAA bad\\nlate-commands:"}'
	)!
	assert res4db.status_code == 400
	res4dc := http.fetch(
		method: .put
		url:    '${test_base}/api/settings'
		header: h_json_auth(token)
		data:   '{"base_url_override":"not a url"}'
	)!
	assert res4dc.status_code == 400

	// OS images catalog: replace it with a lab-specific NFS export
	res4e := http.fetch(
		method: .put
		url:    '${test_base}/api/settings'
		header: h_json_auth(token)
		data:   '{"os_images":[{"os_name":"ubuntu","version":"24.04.5","nfs_root":"10.0.0.9:/srv/nfs/ubuntu-24.04","is_default":true}]}'
	)!
	assert res4e.status_code == 200
	catalog := json2.decode[SettingsRes](res4e.body)!
	assert catalog.os_images.len == 1
	assert catalog.os_images[0].nfs_root == '10.0.0.9:/srv/nfs/ubuntu-24.04'
	assert catalog.os_images[0].is_default

	// no default flag -> the first row becomes the default
	res4f := http.fetch(
		method: .put
		url:    '${test_base}/api/settings'
		header: h_json_auth(token)
		data:   '{"os_images":[{"os_name":"ubuntu","version":"24.04.5","nfs_root":"10.0.0.9:/srv/nfs/ubuntu-24.04"}]}'
	)!
	assert res4f.status_code == 200
	assert json2.decode[SettingsRes](res4f.body)!.os_images[0].is_default

	// invalid catalogs are rejected wholesale
	res4g := http.fetch(
		method: .put
		url:    '${test_base}/api/settings'
		header: h_json_auth(token)
		data:   '{"os_images":[{"os_name":"fedora","version":"41","nfs_root":"10.0.0.9:/srv/nfs/fedora"}]}'
	)!
	assert res4g.status_code == 400
	res4h := http.fetch(
		method: .put
		url:    '${test_base}/api/settings'
		header: h_json_auth(token)
		data:   '{"os_images":[{"os_name":"ubuntu","version":"99.99","nfs_root":"10.0.0.9:/srv/nfs/ubuntu-24.04"}]}'
	)!
	assert res4h.status_code == 400
	res4i := http.fetch(
		method: .put
		url:    '${test_base}/api/settings'
		header: h_json_auth(token)
		data:   '{"os_images":[{"os_name":"ubuntu","version":"24.04.5","nfs_root":"10.0.0.9"}]}'
	)!
	assert res4i.status_code == 400
	res4j := http.fetch(
		method: .put
		url:    '${test_base}/api/settings'
		header: h_json_auth(token)
		data:   '{"os_images":[{"os_name":"ubuntu","version":"24.04.5","nfs_root":"10.0.0.9:/srv/nfs with space"}]}'
	)!
	assert res4j.status_code == 400
	res4k := http.fetch(
		method: .put
		url:    '${test_base}/api/settings'
		header: h_json_auth(token)
		data:   '{"os_images":[{"os_name":"ubuntu","version":"24.04.5","nfs_root":"10.0.0.9:/srv/nfs/ubuntu-24.04"},{"os_name":"ubuntu","version":"24.04.5","nfs_root":"10.0.0.8:/srv/nfs/other"}]}'
	)!
	assert res4k.status_code == 400

	// a point release of a supported series is valid even when it is not listed
	// in versions() (pinned release without a rebuild)
	res4m := http.fetch(
		method: .put
		url:    '${test_base}/api/settings'
		header: h_json_auth(token)
		data:   '{"os_images":[{"os_name":"ubuntu","version":"26.04.2","nfs_root":"10.0.0.9:/srv/nfs/ubuntu-26.04.2","is_default":true}]}'
	)!
	assert res4m.status_code == 200
	assert json2.decode[SettingsRes](res4m.body)!.os_images[0].version == '26.04.2'
	// ...and an unsupported series is still rejected
	res4m2 := http.fetch(
		method: .put
		url:    '${test_base}/api/settings'
		header: h_json_auth(token)
		data:   '{"os_images":[{"os_name":"ubuntu","version":"26.05","nfs_root":"10.0.0.9:/srv/nfs/ubuntu-26.05"}]}'
	)!
	assert res4m2.status_code == 400
	// restore the catalog the rest of the test relies on
	res4n := http.fetch(
		method: .put
		url:    '${test_base}/api/settings'
		header: h_json_auth(token)
		data:   '{"os_images":[{"os_name":"ubuntu","version":"24.04.5","nfs_root":"10.0.0.9:/srv/nfs/ubuntu-24.04","is_default":true}]}'
	)!
	assert res4n.status_code == 200

	// an empty list keeps the current catalog
	res4l := http.fetch(
		method: .put
		url:    '${test_base}/api/settings'
		header: h_json_auth(token)
		data:   '{"os_images":[]}'
	)!
	assert res4l.status_code == 200
	assert json2.decode[SettingsRes](res4l.body)!.os_images.len == 1

	// create with a lowercase MAC: it must come back UPPERCASE; layout defaults
	// to direct and the install disk round-trips
	res5 := http.fetch(
		method: .post
		url:    '${test_base}/api/machines'
		header: h_json_auth(token)
		data:   '{"mac":"bc:24:11:00:24:99","hostname":"vm-test","password":"secret123","storage_disk":"/dev/nvme1n1","boot_mode":"nfs"}'
	)!
	assert res5.status_code == 200
	created := json2.decode[MachineDto](res5.body)!
	assert created.mac == 'BC:24:11:00:24:99'
	assert created.status == 'pending'
	assert created.storage_layout == 'direct'
	assert created.storage_disk == '/dev/nvme1n1'
	assert created.has_password
	assert created.keep_ipxe_first

	// duplicate MAC (different spelling) -> 409
	res6 := http.fetch(
		method: .post
		url:    '${test_base}/api/machines'
		header: h_json_auth(token)
		data:   '{"mac":"BC-24-11-00-24-99"}'
	)!
	assert res6.status_code == 409

	// invalid MAC -> 400
	res7 := http.fetch(
		method: .post
		url:    '${test_base}/api/machines'
		header: h_json_auth(token)
		data:   '{"mac":"zz:zz"}'
	)!
	assert res7.status_code == 400

	// invalid storage_disk (not a /dev/... path) -> 400
	res7b := http.fetch(
		method: .post
		url:    '${test_base}/api/machines'
		header: h_json_auth(token)
		data:   '{"mac":"bc:24:11:00:24:02","storage_disk":"sda"}'
	)!
	assert res7b.status_code == 400

	// a machine pinned to an image missing from the catalog -> 400
	res7c := http.fetch(
		method: .post
		url:    '${test_base}/api/machines'
		header: h_json_auth(token)
		data:   '{"mac":"bc:24:11:00:24:03","os_version":"99.99"}'
	)!
	assert res7c.status_code == 400

	// identity fields are validated at the boundary: injected hostname,
	// username or ssh keys must never reach the autoinstall YAML
	res7d := http.fetch(
		method: .post
		url:    '${test_base}/api/machines'
		header: h_json_auth(token)
		data:   '{"mac":"bc:24:11:00:24:04","hostname":"vm test"}'
	)!
	assert res7d.status_code == 400
	res7e := http.fetch(
		method: .post
		url:    '${test_base}/api/machines'
		header: h_json_auth(token)
		data:   '{"mac":"bc:24:11:00:24:05","username":"Root"}'
	)!
	assert res7e.status_code == 400
	res7f := http.fetch(
		method: .post
		url:    '${test_base}/api/machines'
		header: h_json_auth(token)
		data:   '{"mac":"bc:24:11:00:24:06","ssh_keys":"ssh-ed25519 AAAA k\\nlate-commands:"}'
	)!
	assert res7f.status_code == 400
	res7g := http.fetch(
		method: .post
		url:    '${test_base}/api/machines'
		header: h_json_auth(token)
		data:   '{"mac":"bc:24:11:00:24:07","nfs_root":"bad path"}'
	)!
	assert res7g.status_code == 400

	// a valid per-machine nfs_root override is accepted
	res7h := http.fetch(
		method: .post
		url:    '${test_base}/api/machines'
		header: h_json_auth(token)
		data:   '{"mac":"bc:24:11:00:24:08","hostname":"nfs-override","nfs_root":"10.0.0.9:/srv/nfs/ubuntu-24.04"}'
	)!
	assert res7h.status_code == 200
	override := json2.decode[MachineDto](res7h.body)!
	assert override.nfs_root == '10.0.0.9:/srv/nfs/ubuntu-24.04'
	res7i := http.fetch(
		method: .delete
		url:    '${test_base}/api/machines/${override.id}'
		header: h_auth(token)
	)!
	assert res7i.status_code == 200

	// update only provided fields; the password hash must survive
	res8 := http.fetch(
		method: .put
		url:    '${test_base}/api/machines/${created.id}'
		header: h_json_auth(token)
		data:   '{"hostname":"renamed","username":"timi","ssh_keys":"ssh-ed25519 AAAA test@host","notes":"lab node","storage_layout":"zfs","storage_disk":"auto"}'
	)!
	assert res8.status_code == 200
	updated := json2.decode[MachineDto](res8.body)!
	assert updated.hostname == 'renamed'
	assert updated.username == 'timi'
	assert updated.ssh_keys == 'ssh-ed25519 AAAA test@host'
	assert updated.notes == 'lab node'
	assert updated.has_password
	assert updated.storage_layout == 'zfs'
	assert updated.storage_disk == ''
	assert updated.boot_mode == 'nfs'

	// a machine without hostname cannot be approved
	res9 := http.fetch(
		method: .post
		url:    '${test_base}/api/machines'
		header: h_json_auth(token)
		data:   '{"mac":"bc:24:11:00:24:01"}'
	)!
	no_host := json2.decode[MachineDto](res9.body)!
	res10 := http.fetch(
		method: .post
		url:    '${test_base}/api/machines/${no_host.id}/approve'
		header: h_json_auth(token)
		data:   '{}'
	)!
	assert res10.status_code == 400

	// approve
	res11 := http.fetch(
		method: .post
		url:    '${test_base}/api/machines/${created.id}/approve'
		header: h_json_auth(token)
		data:   '{}'
	)!
	assert res11.status_code == 200
	approved := json2.decode[MachineDto](res11.body)!
	assert approved.status == 'approved'
	assert approved.approved_at > 0

	// per-machine keys override the global ones in the generated user-data
	res11b := http.fetch(url: '${test_base}/os/ubuntu/24.04.5/BC:24:11:00:24:99/user-data')!
	assert res11b.status_code == 200
	assert res11b.body.contains('test@host')
	assert !res11b.body.contains('global@host')

	// 'auto' clears the per-machine keys: the machine inherits the global keys again
	res11c := http.fetch(
		method: .put
		url:    '${test_base}/api/machines/${created.id}'
		header: h_json_auth(token)
		data:   '{"ssh_keys":"auto"}'
	)!
	assert res11c.status_code == 200
	assert json2.decode[MachineDto](res11c.body)!.ssh_keys == ''
	res11d := http.fetch(url: '${test_base}/os/ubuntu/24.04.5/BC:24:11:00:24:99/user-data')!
	assert res11d.status_code == 200
	assert res11d.body.contains('global@host')
	assert !res11d.body.contains('test@host')

	// 'auto' clears the per-machine nfs_root override: machine inherits the OS image nfs_root
	res11c_nfs := http.fetch(
		method: .put
		url:    '${test_base}/api/machines/${created.id}'
		header: h_json_auth(token)
		data:   '{"nfs_root":"auto"}'
	)!
	assert res11c_nfs.status_code == 200
	assert json2.decode[MachineDto](res11c_nfs.body)!.nfs_root == ''

	// an empty payload keeps the cleared value
	res11e := http.fetch(
		method: .put
		url:    '${test_base}/api/machines/${created.id}'
		header: h_json_auth(token)
		data:   '{}'
	)!
	assert res11e.status_code == 200
	assert json2.decode[MachineDto](res11e.body)!.ssh_keys == ''

	// boot.ipxe serves the install script with the nfsroot inherited from the
	// settings catalog (assets are ready via the override dir); flips machine to installing
	res11boot := http.fetch(url: '${test_base}/boot.ipxe?mac=BC:24:11:00:24:99')!
	assert res11boot.status_code == 200
	assert res11boot.body.contains('kernel http://')
	assert res11boot.body.contains('nfsroot=10.0.0.9:/srv/nfs/ubuntu-24.04')

	// installing machine rejects configuration changes
	res_installing_reject := http.fetch(
		method: .put
		url:    '${test_base}/api/machines/${created.id}'
		header: h_json_auth(token)
		data:   '{"hostname":"new-name"}'
	)!
	assert res_installing_reject.status_code == 400
	assert res_installing_reject.body.contains('only notes can be updated')

	// installing machine allows updating notes
	res_installing_notes := http.fetch(
		method: .put
		url:    '${test_base}/api/machines/${created.id}'
		header: h_json_auth(token)
		data:   '{"notes":"installing in progress"}'
	)!
	assert res_installing_notes.status_code == 200
	assert json2.decode[MachineDto](res_installing_notes.body)!.notes == 'installing in progress'

	// reinstall bumps install_count and re-arms
	res12 := http.fetch(
		method: .post
		url:    '${test_base}/api/machines/${created.id}/reinstall'
		header: h_auth(token)
	)!
	assert res12.status_code == 200
	reinstalled := json2.decode[MachineDto](res12.body)!
	assert reinstalled.status == 'approved'
	assert reinstalled.install_count == 1

	// phone-home (no auth) flips to installed
	res13 := http.fetch(
		method: .post
		url:    '${test_base}/api/machines/installed'
		data:   'mac=bc:24:11:00:24:99&hostname=renamed'
	)!
	assert res13.status_code == 200
	res14 := http.fetch(url: '${test_base}/api/machines/${created.id}', header: h_auth(token))!
	home := json2.decode[MachineDto](res14.body)!
	assert home.status == 'installed'
	assert home.installed_at > 0

	// installed machine rejects configuration changes
	res_installed_reject := http.fetch(
		method: .put
		url:    '${test_base}/api/machines/${created.id}'
		header: h_json_auth(token)
		data:   '{"hostname":"cannot-change"}'
	)!
	assert res_installed_reject.status_code == 400
	assert res_installed_reject.body.contains('only notes can be updated')

	// installed machine allows updating notes
	res_installed_notes := http.fetch(
		method: .put
		url:    '${test_base}/api/machines/${created.id}'
		header: h_json_auth(token)
		data:   '{"notes":"installed rack 42"}'
	)!
	assert res_installed_notes.status_code == 200
	assert json2.decode[MachineDto](res_installed_notes.body)!.notes == 'installed rack 42'

	// phone-home for unknown MAC -> 404
	res15 := http.fetch(
		method: .post
		url:    '${test_base}/api/machines/installed'
		data:   'mac=aa:bb:cc:dd:ee:ff'
	)!
	assert res15.status_code == 404

	// phone-home with an invalid hostname is rejected without side effects
	res15b := http.fetch(
		method: .post
		url:    '${test_base}/api/machines/installed'
		data:   'mac=bc:24:11:00:24:99&hostname=bad%20name'
	)!
	assert res15b.status_code == 400

	// filter by status
	res16 := http.fetch(url: '${test_base}/api/machines?status=pending', header: h_auth(token))!
	assert json2.decode[[]MachineDto](res16.body)!.len == 1

	// delete
	res17 := http.fetch(
		method: .delete
		url:    '${test_base}/api/machines/${created.id}'
		header: h_auth(token)
	)!
	assert res17.status_code == 200
	res18 := http.fetch(url: '${test_base}/api/machines', header: h_auth(token))!
	assert json2.decode[[]MachineDto](res18.body)!.len == 1

	// first PXE boot of an unknown MAC auto-creates a pending machine tracking
	// the catalog's default image (nfs_root stays empty = inherit)
	res18b := http.fetch(url: '${test_base}/boot.ipxe?mac=aa:bb:cc:00:11:22')!
	assert res18b.status_code == 200
	assert res18b.body.contains('waiting for approval')
	res18c := http.fetch(url: '${test_base}/api/machines', header: h_auth(token))!
	auto_created := json2.decode[[]MachineDto](res18c.body)!.filter(it.mac == 'AA:BB:CC:00:11:22')
	assert auto_created.len == 1
	assert auto_created[0].os_name == 'ubuntu'
	assert auto_created[0].os_version == '24.04.5'
	assert auto_created[0].nfs_root == ''

	// assets fetch: all rows, a single catalog row, and validation
	res18d := http.fetch(
		method: .post
		url:    '${test_base}/api/assets/fetch'
		header: h_json_auth(token)
		data:   '{}'
	)!
	assert res18d.status_code == 200
	res18e := http.fetch(
		method: .post
		url:    '${test_base}/api/assets/fetch'
		header: h_json_auth(token)
		data:   '{"os_name":"ubuntu","version":"24.04.5"}'
	)!
	assert res18e.status_code == 200
	res18f := http.fetch(
		method: .post
		url:    '${test_base}/api/assets/fetch'
		header: h_json_auth(token)
		data:   '{"os_name":"ubuntu","version":"99.99"}'
	)!
	assert res18f.status_code == 400
	res18g := http.fetch(
		method: .post
		url:    '${test_base}/api/assets/fetch'
		header: h_json_auth(token)
		data:   '{"os_name":"ubuntu"}'
	)!
	assert res18g.status_code == 400

	// a machine whose image was removed from the catalog gets a clear error
	app.st.set_os_images([]store.OsImage{})!
	res18h := http.fetch(url: '${test_base}/boot.ipxe?mac=BC:24:11:00:24:01')!
	assert res18h.status_code == 200
	assert res18h.body.contains('is not configured')

	// logout invalidates the token
	res19 := http.fetch(method: .post, url: '${test_base}/api/auth/logout', header: h_auth(token))!
	assert res19.status_code == 200
	res20 := http.fetch(url: '${test_base}/api/auth/me', header: h_auth(token))!
	assert res20.status_code == 401
}

fn test_boundary_validators_reject_injection() {
	assert (hostname_from('vm-test') or { '' }) == 'vm-test'
	if _ := hostname_from('vm test') {
		assert false, 'hostname with a space must be rejected'
	}
	if _ := hostname_from('a_b') {
		assert false, 'hostname with an underscore must be rejected'
	}
	if _ := hostname_from('-lead') {
		assert false, 'hostname with a leading hyphen must be rejected'
	}
	assert (username_from('timi') or { '' }) == 'timi'
	if _ := username_from('Root') {
		assert false, 'uppercase username must be rejected'
	}
	if _ := username_from("x'y") {
		assert false, 'quote in username must be rejected'
	}
	if _ := ssh_keys_from('ssh-ed25519 AAAA k\nlate-commands:') {
		assert false, 'multi-line ssh key injection must be rejected'
	}
	if _ := ssh_keys_from("ssh-ed25519 AAAA it's") {
		assert false, 'quote in ssh key comment must be rejected'
	}
	assert (ssh_keys_from('ssh-ed25519 AAAA k\nssh-rsa AAAAB3Nza') or { '' }) == 'ssh-ed25519 AAAA k\nssh-rsa AAAAB3Nza'
	assert (validate_nfs_root('10.0.0.9:/srv/nfs/x') or { '' }) == '10.0.0.9:/srv/nfs/x'
	if _ := validate_nfs_root('10.0.0.9:/srv/nfs\nx') {
		assert false, 'newline in nfs_root must be rejected'
	}
	assert is_valid_base_url('http://192.168.250.10:4793')
	assert is_valid_base_url('https://boot.example.com')
	assert !is_valid_base_url('not a url')
	assert !is_valid_base_url('http://host;reboot')
	assert !is_valid_base_url('http://h\nost')
}

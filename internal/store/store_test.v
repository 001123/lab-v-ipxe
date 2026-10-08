module store

fn open_mem() &Store {
	return open(':memory:') or { panic(err) }
}

fn test_migrate_and_seed_admin() {
	mut s := open_mem()
	s.migrate()!
	s.seed_admin('admin@ipxe.local', 'admin@pwd')!
	// seeding twice must be a no-op
	s.seed_admin('admin@ipxe.local', 'admin@pwd')!
	assert s.db.q_int('select count(*) from users')! == 1

	u := s.user_by_email('admin@ipxe.local') or { panic('seeded user missing') }
	assert verify_password(u.password_hash, 'admin@pwd')
	assert !verify_password(u.password_hash, 'wrong-pass')

	id_user := s.user_by_id(u.id) or { panic('user_by_id missing') }
	assert id_user.email == 'admin@ipxe.local'
}

fn test_user_missing() {
	mut s := open_mem()
	s.migrate()!
	assert s.user_by_email('nobody@x.y') == none
	assert s.user_by_id(42) == none
}

fn test_settings_upsert() {
	mut s := open_mem()
	s.migrate()!
	assert s.setting('nfs_root_default') == none
	s.set_setting('nfs_root_default', '10.0.0.1:/srv/nfs/ubuntu-24.04')!
	assert s.setting_or('nfs_root_default', 'fallback') == '10.0.0.1:/srv/nfs/ubuntu-24.04'
	s.set_setting('nfs_root_default', '10.0.0.2:/other')!
	assert s.setting_or('nfs_root_default', 'fallback') == '10.0.0.2:/other'
	assert s.setting_or('absent_key', 'fallback') == 'fallback'
	assert s.setting(setting_ssh_keys) == none
	s.set_setting(setting_ssh_keys, 'ssh-ed25519 GLOBAL')!
	assert s.setting_or(setting_ssh_keys, '') == 'ssh-ed25519 GLOBAL'
}

fn test_machine_defaults_and_storage_disk() {
	mut s := open_mem()
	s.migrate()!
	mut m := Machine{
		mac:      'BC:24:11:00:24:99'
		mac_key:  'bc2411002499'
		hostname: 'vm-test'
	}
	assert m.storage_layout == .direct
	assert m.storage_disk == ''
	assert m.keep_ipxe_first
	s.machine_save(mut m)!
	got := s.machine_by_id(m.id) or { panic('machine missing') }
	assert got.storage_layout == .direct
	assert got.storage_disk == ''
	assert got.keep_ipxe_first

	mut m2 := got
	m2.storage_layout = .zfs
	m2.storage_disk = '/dev/nvme1n1'
	m2.keep_ipxe_first = false
	s.machine_save(mut m2)!
	got2 := s.machine_by_id(m2.id) or { panic('machine missing') }
	assert got2.storage_layout == .zfs
	assert got2.storage_disk == '/dev/nvme1n1'
	assert !got2.keep_ipxe_first
}

fn test_migrate_adds_storage_disk_column_to_legacy_table() {
	mut s := open_mem()
	// minimal "old" machines table without storage_disk; migrate must keep the
	// existing table and add the new column via alter table
	s.db.exec('create table machines (id integer primary key, mac text not null, mac_key text not null)')!
	s.migrate()!
	has_disk := s.db.q_int("select count(*) from pragma_table_info('machines') where name = 'storage_disk'")!
	assert has_disk == 1
	has_keep_pxe := s.db.q_int("select count(*) from pragma_table_info('machines') where name = 'keep_ipxe_first'")!
	assert has_keep_pxe == 1
}

fn test_os_images_roundtrip() {
	mut s := open_mem()
	s.migrate()!
	assert s.os_images() == []
	s.set_os_images([
		OsImage{
			os_name:  'ubuntu'
			version:  '26.04'
			nfs_root: '10.0.0.1:/srv/nfs/ubuntu-26.04'
		},
		OsImage{
			os_name:    'ubuntu'
			version:    '24.04'
			nfs_root:   '10.0.0.1:/srv/nfs/ubuntu-24.04'
			is_default: true
		},
	])!
	got := s.os_images()
	assert got.len == 2
	assert got[0].version == '26.04'
	assert !got[0].is_default
	assert got[1].is_default
	def := s.default_os_image() or { panic('default image missing') }
	assert def.version == '24.04'
	img := s.os_image_for('ubuntu', '26.04') or { panic('image missing') }
	assert img.nfs_root == '10.0.0.1:/srv/nfs/ubuntu-26.04'
	assert s.os_image_for('ubuntu', '99.99') == none
}

fn test_os_images_invalid_json_returns_empty() {
	mut s := open_mem()
	s.migrate()!
	s.set_setting(setting_os_images, 'not-json')!
	assert s.os_images() == []
	assert s.default_os_image() == none
}

fn test_os_images_default_falls_back_to_first_row() {
	mut s := open_mem()
	s.migrate()!
	s.set_os_images([
		OsImage{
			os_name:  'ubuntu'
			version:  '26.04'
			nfs_root: '10.0.0.1:/srv/nfs/ubuntu-26.04'
		},
		OsImage{
			os_name:  'ubuntu'
			version:  '24.04'
			nfs_root: '10.0.0.1:/srv/nfs/ubuntu-24.04'
		},
	])!
	def := s.default_os_image() or { panic('default image missing') }
	assert def.version == '26.04'
}

fn test_seed_os_images_from_legacy_keys() {
	mut s := open_mem()
	s.migrate()!
	s.set_setting(setting_nfs_root, '10.0.0.9:/srv/nfs/ubuntu-24.04')!
	s.set_setting(setting_ubuntu_version, '24.04')!
	seeded := s.seed_os_images('fallback:/x', '99.99')!
	assert seeded
	got := s.os_images()
	assert got.len == 1
	assert got[0].os_name == 'ubuntu'
	assert got[0].version == '24.04'
	assert got[0].nfs_root == '10.0.0.9:/srv/nfs/ubuntu-24.04'
	assert got[0].is_default
	assert s.setting(setting_nfs_root) == none
	assert s.setting(setting_ubuntu_version) == none
	// seeding again must be a no-op
	reseeded := s.seed_os_images('other:/y', '88.88')!
	assert !reseeded
	assert s.os_images()[0].version == '24.04'
}

fn test_seed_os_images_fallbacks() {
	mut s := open_mem()
	s.migrate()!
	seeded := s.seed_os_images('10.0.0.1:/srv/nfs/ubuntu-24.04', '24.04')!
	assert seeded
	got := s.os_images()
	assert got.len == 1
	assert got[0].os_name == 'ubuntu'
	assert got[0].version == '24.04'
	assert got[0].nfs_root == '10.0.0.1:/srv/nfs/ubuntu-24.04'
	assert got[0].is_default
}

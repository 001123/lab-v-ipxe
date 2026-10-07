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
}

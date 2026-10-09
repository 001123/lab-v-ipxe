module store

import db.sqlite

// setting_nfs_root and setting_ubuntu_version are legacy keys: only read once
// by seed_os_images to migrate into the os_images catalog, then deleted.
pub const setting_nfs_root = 'nfs_root_default'
pub const setting_ubuntu_version = 'ubuntu_version'
pub const setting_os_images = 'os_images'
pub const setting_base_url = 'base_url_override'
pub const setting_ubuntu_iso = 'ubuntu_iso_override'
pub const setting_ssh_keys = 'ssh_keys_default'
pub const setting_apt_mirror = 'apt_mirror_default'

pub fn (s &Store) setting(key string) ?string {
	s.mu.lock()
	defer {
		s.mu.unlock()
	}
	rows := s.db.exec_param('select value from settings where key = ? limit 1', key) or {
		[]sqlite.Row{}
	}
	if rows.len == 0 {
		return none
	}
	return rows[0].val(0)
}

pub fn (s &Store) set_setting(key string, value string) ! {
	s.mu.lock()
	defer {
		s.mu.unlock()
	}
	_ := s.db.exec_param2('insert into settings(key, value) values(?, ?) on conflict(key) do update set value = excluded.value',
		key, value)!
}

pub fn (s &Store) setting_or(key string, fallback string) string {
	return s.setting(key) or { fallback }
}

pub fn (s &Store) delete_setting(key string) ! {
	s.mu.lock()
	defer {
		s.mu.unlock()
	}
	_ := s.db.exec_param('delete from settings where key = ?', key)!
}

// delete_token removes a single session token by value (logout).
pub fn (s &Store) delete_token(value string) ! {
	s.mu.lock()
	defer {
		s.mu.unlock()
	}
	_ := s.db.exec_param('delete from Token where value = ?', value)!
}

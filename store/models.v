module store

import time

pub enum MachineStatus {
	pending
	approved
	installing
	installed
}

pub enum BootMode {
	nfs
	http
}

pub enum StorageLayout {
	zfs
	direct
	lvm
}

@[table: 'machines']
pub struct Machine {
pub mut:
	id             int @[primary; sql: serial]
	mac            string
	mac_key        string
	hostname       string
	status         MachineStatus = .pending
	boot_mode      BootMode      = .nfs
	storage_layout StorageLayout = .zfs
	os_name        string        = 'ubuntu'
	os_version     string        = '24.04'
	username       string        = 'ubuntu'
	password_hash  string
	ssh_keys       string
	nfs_root       string
	notes          string
	auto_created   bool
	install_count  int
	approved_at    i64
	installed_at   i64
	last_seen_at   i64
	created_at     i64
	updated_at     i64
}

@[table: 'users']
pub struct User {
pub mut:
	id            int @[primary; sql: serial]
	email         string
	password_hash string
	created_at    i64
}

@[table: 'settings']
pub struct Setting {
pub mut:
	key   string @[primary]
	value string
}

pub fn now_unix() i64 {
	return time.now().unix()
}

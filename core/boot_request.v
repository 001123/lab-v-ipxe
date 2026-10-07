module core

import store

// BootRequest is the plain-data input providers render from. It is assembled
// from a store.Machine plus the request context (base URL, settings defaults).
pub struct BootRequest {
pub mut:
	base_url       string // "http://host:port" the machine booted from
	mac            string // UPPERCASE colon form
	mac_key        string // 12 lowercase hex chars
	hostname       string
	username       string
	password_hash  string // '' -> provider default
	ssh_keys       string // newline-joined authorized_keys
	nfs_root       string // resolved (machine override or global default)
	os_name        string
	os_version     string
	arch           string
	storage_layout store.StorageLayout
	install_count  int
	boot_mode      store.BootMode
}

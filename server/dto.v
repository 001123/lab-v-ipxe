module server

import store

pub struct LoginPayload {
pub:
	email    string
	password string
}

pub struct UserDto {
pub:
	email string
}

pub struct LoginRes {
pub:
	token string
	user  UserDto
}

pub struct MessageRes {
pub:
	message string
}

pub struct OkRes {
pub:
	ok bool
}

pub struct MachineDto {
pub:
	id             int
	mac            string
	hostname       string
	status         string
	boot_mode      string
	storage_layout string
	storage_disk   string
	os_name        string
	os_version     string
	username       string
	ssh_keys       string
	nfs_root       string
	notes          string
	install_count  int
	has_password   bool
	auto_created   bool
	approved_at    i64
	installed_at   i64
	last_seen_at   i64
	created_at     i64
	updated_at     i64
}

// MachinePayload is accepted by create/update/approve. Empty strings mean
// "keep the default / keep the current value" (password: keep current hash);
// ssh_keys 'auto' clears the per-machine keys (machine inherits the global ones).
pub struct MachinePayload {
pub:
	mac            string
	hostname       string
	username       string
	password       string
	ssh_keys       string
	nfs_root       string
	notes          string
	os_name        string
	os_version     string
	boot_mode      string
	storage_layout string
	storage_disk   string
}

fn machine_to_dto(m store.Machine) MachineDto {
	return MachineDto{
		id:             m.id
		mac:            m.mac
		hostname:       m.hostname
		status:         m.status.str()
		boot_mode:      m.boot_mode.str()
		storage_layout: m.storage_layout.str()
		storage_disk:   m.storage_disk
		os_name:        m.os_name
		os_version:     m.os_version
		username:       m.username
		ssh_keys:       m.ssh_keys
		nfs_root:       m.nfs_root
		notes:          m.notes
		install_count:  m.install_count
		has_password:   m.password_hash != ''
		auto_created:   m.auto_created
		approved_at:    m.approved_at
		installed_at:   m.installed_at
		last_seen_at:   m.last_seen_at
		created_at:     m.created_at
		updated_at:     m.updated_at
	}
}

fn status_filter_from(s string) ?store.MachineStatus {
	match s {
		'pending' { return .pending }
		'approved' { return .approved }
		'installing' { return .installing }
		'installed' { return .installed }
		else { return none }
	}
}

fn boot_mode_from(s string) ?store.BootMode {
	match s {
		'nfs' { return .nfs }
		'http' { return .http }
		else { return none }
	}
}

fn storage_layout_from(s string) ?store.StorageLayout {
	match s {
		'zfs' { return .zfs }
		'direct' { return .direct }
		'lvm' { return .lvm }
		else { return none }
	}
}

// storage_disk_from validates an installer disk match path (/dev/... form,
// e.g. /dev/nvme0n1 or /dev/disk/by-id/...). '' or 'auto' -> no match
// (subiquity picks the largest disk).
fn storage_disk_from(s string) !string {
	v := s.trim_space()
	if v == '' || v == 'auto' {
		return ''
	}
	if !v.starts_with('/dev/') {
		return error('invalid storage_disk "${s}" (expected a /dev/... path or "auto")')
	}
	for c in v {
		if !(c >= `a` && c <= `z`) && !(c >= `A` && c <= `Z`) && !(c >= `0` && c <= `9`)
			&& c !in [`/`, `_`, `-`, `.`, `:`, `+`] {
			return error('invalid storage_disk "${s}" (expected a /dev/... path or "auto")')
		}
	}
	return v
}

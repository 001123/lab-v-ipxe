module server

import internal.store

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
	id              int
	mac             string
	hostname        string
	status          string
	boot_mode       string
	storage_layout  string
	storage_disk    string
	keep_ipxe_first bool
	os_name         string
	os_version      string
	username        string
	ssh_keys        string
	nfs_root        string
	notes           string
	install_count   int
	has_password    bool
	auto_created    bool
	approved_at     i64
	installed_at    i64
	last_seen_at    i64
	created_at      i64
	updated_at      i64
}

// MachinePayload is accepted by create/update/approve. Empty strings mean
// "keep the default / keep the current value" (password: keep current hash);
// ssh_keys / nfs_root 'auto' clears the per-machine override (machine inherits the global/image ones).
pub struct MachinePayload {
pub:
	mac             string
	hostname        string
	username        string
	password        string
	ssh_keys        string
	nfs_root        string
	notes           string
	os_name         string
	os_version      string
	boot_mode       string
	storage_layout  string
	storage_disk    string
	keep_ipxe_first ?bool
}

fn machine_to_dto(m store.Machine) MachineDto {
	return MachineDto{
		id:              m.id
		mac:             m.mac
		hostname:        m.hostname
		status:          m.status.str()
		boot_mode:       m.boot_mode.str()
		storage_layout:  m.storage_layout.str()
		storage_disk:    m.storage_disk
		keep_ipxe_first: m.keep_ipxe_first
		os_name:         m.os_name
		os_version:      m.os_version
		username:        m.username
		ssh_keys:        m.ssh_keys
		nfs_root:        m.nfs_root
		notes:           m.notes
		install_count:   m.install_count
		has_password:    m.password_hash != ''
		auto_created:    m.auto_created
		approved_at:     m.approved_at
		installed_at:    m.installed_at
		last_seen_at:    m.last_seen_at
		created_at:      m.created_at
		updated_at:      m.updated_at
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

// hostname_from validates an RFC 1123 host label (single label, no dots):
// 1-63 letters, digits or hyphens, not starting or ending with '-'. The value
// is interpolated into the autoinstall YAML and the meta-data.
fn hostname_from(s string) !string {
	v := s.trim_space()
	if v == '' || v.len > 63 || v.starts_with('-') || v.ends_with('-') {
		return error('invalid hostname "${s}" (expected an RFC 1123 label: letters, digits, hyphens, max 63 chars)')
	}
	for c in v {
		if !(c >= `a` && c <= `z`) && !(c >= `A` && c <= `Z`) && !(c >= `0` && c <= `9`)
			&& c != `-` {
			return error('invalid hostname "${s}" (expected an RFC 1123 label: letters, digits, hyphens, max 63 chars)')
		}
	}
	return v
}

// username_from validates the admin username subiquity creates and the
// late-commands interpolate into a root shell: ^[a-z_][a-z0-9_-]*$, max 32
// chars (Linux USERNAME_MAX).
fn username_from(s string) !string {
	v := s.trim_space()
	if v == '' || v.len > 32 {
		return error('invalid username "${s}" (expected ^[a-z_][a-z0-9_-]*$, max 32 chars)')
	}
	first := v[0]
	if first != `_` && !(first >= `a` && first <= `z`) {
		return error('invalid username "${s}" (expected ^[a-z_][a-z0-9_-]*$, max 32 chars)')
	}
	for c in v[1..] {
		if !(c >= `a` && c <= `z`) && !(c >= `0` && c <= `9`) && c != `_` && c != `-` {
			return error('invalid username "${s}" (expected ^[a-z_][a-z0-9_-]*$, max 32 chars)')
		}
	}
	return v
}

const ssh_key_max_line_len = 8192

// ssh_keys_from validates the newline-joined authorized_keys blob: every
// non-empty line must look like "<ssh-/ecdsa-/sk- type> <base64> [comment]"
// with printable ASCII and no single quotes. The renderer JSON-encodes each
// line as well; this is the input-boundary half of the YAML-injection
// defence.
fn ssh_keys_from(s string) !string {
	for line in s.split_into_lines() {
		k := line.trim_space()
		if k == '' {
			continue
		}
		bad := 'invalid ssh_keys line "${k}" (expected "<type> <base64-key> [comment]", printable ASCII without quotes)'
		if k.len > ssh_key_max_line_len {
			return error(bad)
		}
		fields := k.fields()
		if fields.len < 2 {
			return error(bad)
		}
		key_type := fields[0]
		if !key_type.starts_with('ssh-') && !key_type.starts_with('ecdsa-')
			&& !key_type.starts_with('sk-') {
			return error(bad)
		}
		for c in key_type {
			if !(c >= `a` && c <= `z`) && !(c >= `0` && c <= `9`) && c !in [`@`, `.`, `_`, `-`] {
				return error(bad)
			}
		}
		for c in fields[1] {
			if !(c >= `a` && c <= `z`) && !(c >= `A` && c <= `Z`) && !(c >= `0` && c <= `9`)
				&& c !in [`+`, `/`, `=`] {
				return error(bad)
			}
		}
		for c in k {
			if (c < ` ` && c != `\t`) || c > `~` || c == `'` {
				return error(bad)
			}
		}
	}
	return s.trim_space()
}

// base_url_from validates the externally reachable URL embedded verbatim in
// boot scripts and late-commands: http(s)://host[:port][/path], no whitespace
// or shell/YAML metacharacters.
fn base_url_from(s string) !string {
	v := s.trim_space()
	if !is_valid_base_url(v) {
		return error('invalid base_url "${s}" (expected http://host[:port][/path])')
	}
	return v
}

fn is_valid_base_url(v string) bool {
	if v.len == 0 || v.len > 253 {
		return false
	}
	mut rest := v
	if rest.starts_with('https://') {
		rest = rest[8..]
	} else if rest.starts_with('http://') {
		rest = rest[7..]
	} else {
		return false
	}
	if rest == '' {
		return false
	}
	for c in rest {
		if !(c >= `a` && c <= `z`) && !(c >= `A` && c <= `Z`) && !(c >= `0` && c <= `9`)
			&& c !in [`/`, `:`, `.`, `-`, `_`, `[`, `]`] {
			return false
		}
	}
	return true
}

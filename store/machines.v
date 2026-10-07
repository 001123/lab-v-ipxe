module store

pub fn (s &Store) machines_list(status ?MachineStatus) []Machine {
	s.mu.lock()
	defer {
		s.mu.unlock()
	}
	if st := status {
		return sql s.db {
			select from Machine where status == st order by id
		} or { []Machine{} }
	}
	return sql s.db {
		select from Machine order by id
	} or { []Machine{} }
}

pub fn (s &Store) machine_by_id(id int) ?Machine {
	s.mu.lock()
	defer {
		s.mu.unlock()
	}
	rows := sql s.db {
		select from Machine where id == id limit 1
	} or { []Machine{} }
	if rows.len == 0 {
		return none
	}
	return rows[0]
}

pub fn (s &Store) machine_by_mac_key(mac_key string) ?Machine {
	s.mu.lock()
	defer {
		s.mu.unlock()
	}
	rows := sql s.db {
		select from Machine where mac_key == mac_key limit 1
	} or { []Machine{} }
	if rows.len == 0 {
		return none
	}
	return rows[0]
}

// machine_save inserts when id == 0, otherwise updates every mutable column.
pub fn (s &Store) machine_save(mut m Machine) ! {
	s.mu.lock()
	defer {
		s.mu.unlock()
	}
	now := now_unix()
	if m.id == 0 {
		m.created_at = now
		m.updated_at = now
		sql s.db {
			insert m into Machine
		}!
		m.id = s.db.last_id()
	} else {
		m.updated_at = now
		sql s.db {
			update Machine set mac = m.mac, mac_key = m.mac_key, hostname = m.hostname, status = m.status, boot_mode = m.boot_mode, storage_layout = m.storage_layout, storage_disk = m.storage_disk, os_name = m.os_name, os_version = m.os_version, username = m.username, password_hash = m.password_hash, ssh_keys = m.ssh_keys, nfs_root = m.nfs_root, notes = m.notes, auto_created = m.auto_created, install_count = m.install_count, approved_at = m.approved_at, installed_at = m.installed_at, last_seen_at = m.last_seen_at, updated_at = m.updated_at where id == m.id
		}!
	}
}

pub fn (s &Store) machine_delete(id int) ! {
	s.mu.lock()
	defer {
		s.mu.unlock()
	}
	sql s.db {
		delete from Machine where id == id
	}!
}

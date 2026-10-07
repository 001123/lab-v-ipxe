module store

import crypto.bcrypt
import db.sqlite
import sync
import time

@[heap]
pub struct Store {
pub mut:
	mu sync.Mutex
	db sqlite.DB
}

pub fn open(path string) !&Store {
	db := sqlite.connect(path)!
	// WAL is not in sqlite.JournalMode enum, set it via pragma.
	db.exec('pragma journal_mode = wal')!
	db.busy_timeout(5000)
	db.exec('pragma foreign_keys = on')!
	return &Store{
		db: db
	}
}

pub fn (s &Store) ping() ! {
	s.mu.lock()
	defer {
		s.mu.unlock()
	}
	_ := s.db.q_int('select 1')!
}

pub fn (s &Store) migrate() ! {
	s.mu.lock()
	defer {
		s.mu.unlock()
	}
	sql s.db {
		create table Machine
	}!
	sql s.db {
		create table User
	}!
	sql s.db {
		create table Setting
	}!
	_ := s.db.exec('create unique index if not exists idx_machines_mac_key on machines(mac_key)')!
}

pub fn (s &Store) seed_admin(email string, password string) ! {
	s.mu.lock()
	defer {
		s.mu.unlock()
	}
	count := s.db.q_int('select count(*) from users')!
	if count > 0 {
		return
	}
	hash := bcrypt.generate_from_password(password.bytes(), 10)!
	user := User{
		email:         email
		password_hash: hash
		created_at:    time.now().unix()
	}
	sql s.db {
		insert user into User
	}!
	eprintln('[store] seeded default admin user: ${email}')
}

module store

import crypto.bcrypt

pub fn (s &Store) user_by_email(email string) ?User {
	s.mu.lock()
	defer {
		s.mu.unlock()
	}
	users := sql s.db {
		select from User where email == email limit 1
	} or { []User{} }
	if users.len == 0 {
		return none
	}
	return users[0]
}

pub fn (s &Store) user_by_id(id int) ?User {
	s.mu.lock()
	defer {
		s.mu.unlock()
	}
	users := sql s.db {
		select from User where id == id limit 1
	} or { []User{} }
	if users.len == 0 {
		return none
	}
	return users[0]
}

pub fn verify_password(hash string, password string) bool {
	bcrypt.compare_hash_and_password(password.bytes(), hash.bytes()) or { return false }
	return true
}

module sha512crypt

import crypto.sha512
import rand

// SHA-512 crypt ("$6$", Ulrich Drepper's SHA-crypt spec), as used by Linux
// /etc/shadow, openssl passwd -6 and cloud-init user-data passwords.

pub const default_rounds = 5000
pub const min_rounds = 1000
pub const max_rounds = 999_999_999
pub const salt_len_max = 16

const b64_alphabet = './0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'

// P64 byte permutation from the SHA-crypt spec, in encoding-group order:
// group k packs bytes (c[perm[3k]] << 16) | (c[perm[3k+1]] << 8) | c[perm[3k+2]].
const perm = [0, 21, 42, 22, 43, 1, 44, 2, 23, 3, 24, 45, 25, 46, 4, 47, 5, 26, 6, 27, 48, 28,
	49, 7, 50, 8, 29, 9, 30, 51, 31, 52, 10, 53, 11, 32, 12, 33, 54, 34, 55, 13, 56, 14, 35, 15,
	36, 57, 37, 58, 16, 59, 17, 38, 18, 39, 60, 40, 61, 19, 62, 20, 41, 63]

// generate_salt returns a fresh 16-char salt from the crypt base64 alphabet
// (rand.string is alphanumeric, a safe subset of the alphabet).
pub fn generate_salt() string {
	return rand.string(salt_len_max)
}

// hash returns the "$6$..." crypt hash. `rounds` below 1000 is clamped to
// 1000; `salt` is truncated to 16 chars, matching glibc behaviour.
pub fn hash(password string, salt string, rounds int) string {
	pw := password.bytes()
	mut slt := salt.bytes()
	if slt.len > salt_len_max {
		slt = slt[..salt_len_max].clone()
	}
	rounds_n := if rounds < min_rounds {
		min_rounds
	} else if rounds > max_rounds {
		max_rounds
	} else {
		rounds
	}
	// alternate digest B = SHA512(P + S + P)
	b := sha512.sum512(cat3(pw, slt, pw))
	// digest A
	mut a_in := []u8{}
	a_in << pw
	a_in << slt
	mut n := pw.len
	for n > 64 {
		a_in << b
		n -= 64
	}
	a_in << b[..n]
	n = pw.len
	for n > 0 {
		if (n & 1) == 1 {
			a_in << b
		} else {
			a_in << pw
		}
		n = n >> 1
	}
	mut c := sha512.sum512(a_in)
	// DP -> byte sequence P
	mut dp_in := []u8{}
	for _ in 0 .. pw.len {
		dp_in << pw
	}
	dp := sha512.sum512(dp_in)
	mut p_seq := []u8{len: pw.len}
	for i in 0 .. pw.len {
		p_seq[i] = dp[i % 64]
	}
	// DS -> byte sequence S (16 + first byte of A repetitions of the salt)
	mut ds_in := []u8{}
	reps := 16 + int(c[0])
	for _ in 0 .. reps {
		ds_in << slt
	}
	ds := sha512.sum512(ds_in)
	mut s_seq := []u8{len: slt.len}
	for i in 0 .. slt.len {
		s_seq[i] = ds[i % 64]
	}
	// main rounds loop
	for round in 0 .. rounds_n {
		mut round_msg := []u8{}
		if (round & 1) == 1 {
			round_msg << p_seq
		} else {
			round_msg << c
		}
		if round % 3 != 0 {
			round_msg << s_seq
		}
		if round % 7 != 0 {
			round_msg << p_seq
		}
		if (round & 1) == 1 {
			round_msg << c
		} else {
			round_msg << p_seq
		}
		c = sha512.sum512(round_msg)
	}
	// encode with the sha512 byte permutation
	mut encoded := []u8{cap: 86}
	for i := 0; i < 64; i += 3 {
		if i + 2 < 64 {
			w := (u32(c[perm[i]]) << 16) | (u32(c[perm[i + 1]]) << 8) | u32(c[perm[i + 2]])
			encoded << b64_alphabet[int(w & 0x3f)]
			encoded << b64_alphabet[int((w >> 6) & 0x3f)]
			encoded << b64_alphabet[int((w >> 12) & 0x3f)]
			encoded << b64_alphabet[int((w >> 18) & 0x3f)]
		} else if i + 1 < 64 {
			w := (u32(c[perm[i]]) << 8) | u32(c[perm[i + 1]])
			encoded << b64_alphabet[int(w & 0x3f)]
			encoded << b64_alphabet[int((w >> 6) & 0x3f)]
			encoded << b64_alphabet[int((w >> 12) & 0x3f)]
		} else {
			w := u32(c[perm[i]])
			encoded << b64_alphabet[int(w & 0x3f)]
			encoded << b64_alphabet[int((w >> 6) & 0x3f)]
		}
	}
	prefix := if rounds_n != default_rounds {
		'$6$rounds=${rounds_n}$'
	} else {
		'$6$'
	}
	return prefix + slt.bytestr() + '$' + encoded.bytestr()
}

fn cat3(a []u8, b []u8, c []u8) []u8 {
	mut out := []u8{cap: a.len + b.len + c.len}
	out << a
	out << b
	out << c
	return out
}

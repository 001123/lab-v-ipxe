module macutils

// normalize converts any common MAC representation (upper/lower case,
// ':'- or '-'-separated, or bare 12 hex chars) into the canonical
// uppercase colon form "AA:BB:CC:DD:EE:FF".
pub fn normalize(input string) !string {
	mut hex := []u8{cap: 12}
	for c in input.trim_space().bytes() {
		if c == `:` || c == `-` || c == `.` {
			continue
		}
		mut u := c
		if u >= `a` && u <= `f` {
			u -= 32
		}
		if !((u >= `0` && u <= `9`) || (u >= `A` && u <= `F`)) {
			return error('invalid MAC address: ${input}')
		}
		hex << u
	}
	if hex.len != 12 {
		return error('invalid MAC address: ${input}')
	}
	mut parts := []string{cap: 6}
	for i := 0; i < 12; i += 2 {
		parts << hex[i..i + 2].bytestr()
	}
	return parts.join(':')
}

// key returns the 12-hex-digit form used as the unique DB key.
pub fn key(normalized string) string {
	return normalized.replace(':', '').to_lower()
}

pub fn is_valid(input string) bool {
	normalize(input) or { return false }
	return true
}

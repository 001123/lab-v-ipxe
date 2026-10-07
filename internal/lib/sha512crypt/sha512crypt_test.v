module sha512crypt

// Official test vectors from Ulrich Drepper's SHA-crypt specification.
// Vector 3 in the spec prints a "rounds=5000$" prefix because the salt string
// itself contained it; our API omits the prefix at the default 5000 rounds,
// so only the digest part is compared there.

fn test_spec_vector_default_rounds() {
	got := hash('Hello world!', 'saltstring', 5000)
	want := '$6$saltstring$svn8UoSVapNtMuq1ukKS4tPQd8iKwSMHWjl/O817G3uBnIFNjnQJuesI68u4OTLiBFdcbYEdFCoEOfaS35inz1'
	assert got == want
}

fn test_spec_vector_10000_rounds_and_salt_truncation() {
	got := hash('Hello world!', 'saltstringsaltstring', 10000)
	want := '$6$rounds=10000$saltstringsaltst$OW1/O6BYHV6BcXZu8QVeXbDWra3Oeqh0sbHbbMCVNSnCM/UrjmM0Dp8vOuZeHBy/YTBmSK6H9qs/y3RnOaw5v.'
	assert got == want
}

fn test_spec_vector_long_salt() {
	got := hash('This is just a test', 'toolongsaltstring', 5000)
	want := '$6$toolongsaltstrin$lQ8jolhgVRVhY4b5pZKaysCLi0QBxGoNeKQzQ3glMhwllF7oGDZxUhx1yxdYcz/e1JSbq3y6JMxxl8audkUEm0'
	assert got == want
}

fn test_spec_vector_long_password_1400_rounds() {
	got := hash('a very much longer text to encrypt.  This one even stretches over morethan one line.',
		'anotherlongsaltstring', 1400)
	want := '$6$rounds=1400$anotherlongsalts$POfYwTEok97VWcjxIiSOjiykti.o/pQs.wPvMxQ6Fm7I6IoYN3CmLs66x9t0oSwbtEW7o7UmJEiDwGqd8p4ur1'
	assert got == want
}

fn test_spec_vector_77777_rounds() {
	got := hash('we have a short salt string but not a short password', 'short', 77777)
	want := '$6$rounds=77777$short$WuQyW2YR.hBNpjjRhpYD/ifIw05xdfeEyQoMxIXbkvr0gge1a1x3yRULJ5CCaUeOxFmtlcGZelFl5CxtgfiAc0'
	assert got == want
}

fn test_spec_vector_123456_rounds() {
	got := hash('a short string', 'asaltof16chars..', 123456)
	want := '$6$rounds=123456$asaltof16chars..$BtCwjqMJGx5hrJhZywWvt0RLE8uZ4oPwcelCjmw2kSYu.Ec6ycULevoBK25fs2xXgMNrCzIMVcgEJAstJeonj1'
	assert got == want
}

fn test_spec_vector_rounds_clamped_to_minimum() {
	got := hash('the minimum number is still observed', 'roundstoolow', 10)
	want := '$6$rounds=1000$roundstoolow$kUMsbe306n21p9R.FRkW3IGn.S9NPN0x50YhH1xhLsPuWGsUSklZt58jaTfF4ZEQpyUNGc0dqbpBYYBaHHrsX.'
	assert got == want
}

fn test_empty_password_is_deterministic() {
	a := hash('', 'abcdefghijklmnop', 5000)
	b := hash('', 'abcdefghijklmnop', 5000)
	assert a == b
	assert a.starts_with('$6$abcdefghijklmnop$')
	assert a.len == 3 + 16 + 1 + 86
}

fn test_generated_salt() {
	s := generate_salt()
	assert s.len == 16
	for ch in s {
		assert './0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'.contains(ch.ascii_str())
	}
	h := hash('ubuntu', s, 5000)
	assert h.starts_with('$6$' + s + '$')
	// same salt + password must reproduce the same digest
	assert hash('ubuntu', s, 5000) == h
}

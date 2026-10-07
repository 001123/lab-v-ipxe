module macutils

fn test_normalize_forms() {
	assert normalize('bc:24:11:00:24:04')! == 'BC:24:11:00:24:04'
	assert normalize('BC-24-11-00-24-04')! == 'BC:24:11:00:24:04'
	assert normalize('bc2411002404')! == 'BC:24:11:00:24:04'
	assert normalize(' bc:24:11:00:24:04 ')!.to_lower() == 'bc:24:11:00:24:04'
	assert key('BC:24:11:00:24:04') == 'bc2411002404'
}

fn test_validity() {
	assert is_valid('52:54:00:99:00:01')
	assert is_valid('525400990001')
	assert !is_valid('52:54:00:99:00')
	assert !is_valid('zz:54:00:99:00:01')
	assert !is_valid('')
}

fn test_normalize_errors() {
	normalize('bad') or {
		assert err.msg().contains('invalid MAC')
		return
	}
	assert false
}

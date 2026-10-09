module boot

import internal.config
import internal.store

fn test_boot_action_table() {
	assert boot_action(.pending, true) == .wait_approval
	assert boot_action(.pending, false) == .wait_approval
	assert boot_action(.approved, true) == .install
	assert boot_action(.approved, false) == .wait_assets
	assert boot_action(.installing, true) == .install
	assert boot_action(.installing, false) == .install
	assert boot_action(.installed, true) == .sanboot
	assert boot_action(.installed, false) == .sanboot
}

fn test_transition_approved_to_installing() {
	mut m := store.Machine{
		status: .approved
	}
	assert transition_after_boot_script(mut m)
	assert m.status == .installing
	assert m.last_seen_at > 0
}

fn test_transition_installing_and_installed_are_stable() {
	mut m := store.Machine{
		status: .installing
	}
	assert !transition_after_boot_script(mut m)
	assert m.status == .installing

	mut done := store.Machine{
		status: .installed
	}
	assert !transition_after_boot_script(mut done)
	assert done.status == .installed
}

fn test_wait_and_sanboot_scripts() {
	w := wait_script('http://10.0.0.5:4793', 'BC:24:11:00:24:99', 'waiting for approval')
	assert w.starts_with('#!ipxe')
	assert w.contains('echo lab-v-ipxe v${config.version}: waiting for approval')
	assert w.contains('chain http://10.0.0.5:4793/boot.ipxe?mac=BC:24:11:00:24:99')
	assert w.contains('sleep 10')

	s := sanboot_script()
	assert s.contains('echo lab-v-ipxe v${config.version}: system installed')
	assert s.contains('sanboot --no-describe --drive 0x80')

	e := error_script('boom')
	assert e.contains('echo lab-v-ipxe v${config.version} ERROR: boom')
}

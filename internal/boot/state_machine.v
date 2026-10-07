module core

import store

// BootAction is what /boot.ipxe should answer with for a given machine state.
pub enum BootAction {
	wait_approval
	wait_assets
	install
	sanboot
}

pub fn boot_action(status store.MachineStatus, assets_ready bool) BootAction {
	return match status {
		.pending { BootAction.wait_approval }
		.approved {
			if assets_ready {
				BootAction.install
			} else {
				BootAction.wait_assets
			}
		}
		.installing { BootAction.install }
		.installed { BootAction.sanboot }
	}
}

// transition_after_boot_script persists the side effects of serving an install
// script: approved -> installing, and the machine was seen. Returns true when
// the status changed (so the caller knows it must save).
pub fn transition_after_boot_script(mut m store.Machine) bool {
	changed := m.status == .approved
	if changed {
		m.status = .installing
	}
	m.last_seen_at = store.now_unix()
	return changed
}

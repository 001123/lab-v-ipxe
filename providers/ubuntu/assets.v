module ubuntu

import os
import sync
import time

pub enum AssetPhase {
	idle
	downloading
	extracting
	ready
	failed
}

pub struct AssetStatus {
pub mut:
	phase        AssetPhase
	version      string
	message      string
	percent      int
	bytes_done   i64
	bytes_total  i64
	source       string
	attempts     int // consecutive failed fetch attempts
	last_fail_at i64 // unix time of the last failure
}

// AssetManager owns the kernel/initrd cache for installer assets. Assets come
// from (in priority order): the cache dir, an override dir, a local ISO, or a
// one-time download from releases.ubuntu.com (see assets_fetch.v). A status is
// tracked per OS version.
@[heap]
pub struct AssetManager {
pub mut:
	cache_dir    string // <data dir>/assets
	override_dir string // LAB_V_IPXE_UBUNTU_ASSETS_DIR
	local_iso    string // LAB_V_IPXE_UBUNTU_ISO
	keep_iso     bool
	mu           sync.Mutex
	statuses     map[string]AssetStatus // key: version
}

pub fn new_assets(cache_dir string, override_dir string, local_iso string, keep_iso bool) &AssetManager {
	return &AssetManager{
		cache_dir:    cache_dir
		override_dir: override_dir
		local_iso:    local_iso
		keep_iso:     keep_iso
		statuses:     map[string]AssetStatus{}
	}
}

// version_dir is the cache directory for one OS version.
pub fn (am &AssetManager) version_dir(version string) string {
	return os.join_path(am.cache_dir, 'ubuntu', version)
}

// path_for resolves a servable asset: local cache first, then the override dir.
pub fn (am &AssetManager) path_for(version string, name string) ?string {
	cached := os.join_path(am.version_dir(version), name)
	if os.exists(cached) && os.file_size(cached) > 0 {
		return cached
	}
	if am.override_dir != '' {
		alt := os.join_path(am.override_dir, name)
		if os.exists(alt) && os.file_size(alt) > 0 {
			return alt
		}
	}
	return none
}

pub fn (am &AssetManager) ready(version string) bool {
	return am.path_for(version, 'vmlinuz') != none && am.path_for(version, 'initrd') != none
}

pub fn (am &AssetManager) status_snapshot(version string) AssetStatus {
	am.mu.lock()
	defer {
		am.mu.unlock()
	}
	return am.statuses[version] or { AssetStatus{ version: version } }
}

fn (mut am AssetManager) set_status(phase AssetPhase, version string, message string) {
	am.mu.lock()
	defer {
		am.mu.unlock()
	}
	mut st := am.statuses[version] or { AssetStatus{ version: version } }
	st.phase = phase
	st.message = message
	if phase == .ready {
		st.percent = 100
	}
	am.statuses[version] = st
}

fn (mut am AssetManager) set_progress(version string, bytes_done i64, bytes_total i64) {
	am.mu.lock()
	defer {
		am.mu.unlock()
	}
	mut st := am.statuses[version] or { AssetStatus{ version: version } }
	st.bytes_done = bytes_done
	st.bytes_total = bytes_total
	st.percent = if bytes_total > 0 {
		int(bytes_done * 100 / bytes_total)
	} else {
		0
	}
	am.statuses[version] = st
}

fn (mut am AssetManager) fail(version string, message string) {
	am.mu.lock()
	mut st := am.statuses[version] or { AssetStatus{ version: version } }
	st.phase = .failed
	st.message = message
	st.attempts++
	st.last_fail_at = time.now().unix()
	am.statuses[version] = st
	am.mu.unlock()
	eprintln('[assets] failed: ${message}')
}

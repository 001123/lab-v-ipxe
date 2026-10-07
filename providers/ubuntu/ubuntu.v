module ubuntu

import core

pub struct Ubuntu {
pub mut:
	assets &AssetManager
}

pub fn new(assets &AssetManager) &Ubuntu {
	return &Ubuntu{
		assets: assets
	}
}

pub fn (u &Ubuntu) name() string {
	return 'ubuntu'
}

pub fn (u &Ubuntu) display_name() string {
	return 'Ubuntu'
}

// versions lists the selectable releases, newest first. A full point release
// (x.y.z) is pinned: assets come from exactly that ISO. A two-part series
// (x.y) tracks the newest .N release. Adding a series is a one-line change;
// point releases of an already-supported series need no code change at all.
pub fn (u &Ubuntu) versions() []string {
	return ['26.04.1', '24.04.5']
}

// supports_version accepts every selectable version plus any other point
// release (x.y.z) of an already-supported series, so a pinned release can be
// added to the catalog without a rebuild.
pub fn (u &Ubuntu) supports_version(version string) bool {
	parts := version.split('.')
	if parts.len == 3 {
		return '${parts[0]}.${parts[1]}' in u.supported_series()
	}
	return version in u.versions()
}

fn (u &Ubuntu) supported_series() []string {
	mut out := []string{}
	for v in u.versions() {
		parts := v.split('.')
		if parts.len == 3 {
			out << '${parts[0]}.${parts[1]}'
		} else {
			out << v
		}
	}
	return out
}

pub fn (u &Ubuntu) assets_ready(req core.BootRequest) bool {
	return u.assets.ready(req.os_version)
}

pub fn (u &Ubuntu) install_script(req core.BootRequest) !string {
	if req.boot_mode == .http {
		return error('boot_mode "http" (netboot=url) is not implemented yet; MVP boots via NFS on Proxmox')
	}
	return nfs_install_script(req)
}

pub fn (u &Ubuntu) user_data(req core.BootRequest) !string {
	return render_user_data(req)
}

pub fn (u &Ubuntu) meta_data(req core.BootRequest) !string {
	return render_meta_data(req)
}

module ubuntu

import core

pub const default_version = '24.04'

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

// versions lists the supported releases, newest first. Adding a release (e.g.
// '26.04') is a one-line change; assets are discovered per version.
pub fn (u &Ubuntu) versions() []string {
	return [default_version]
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

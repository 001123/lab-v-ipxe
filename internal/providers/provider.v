module providers

import core

// OSProvider renders boot configuration for one operating system family.
// Future OSes (talos, suse, rocky, ...) implement this interface and register
// themselves in the server's provider map. Implementers must provide
// name/display_name/versions; versions() is ordered newest-first and drives
// the version dropdown in the UI.
pub interface OSProvider {
	name() string
	display_name() string
	versions() []string
	// supports_version reports whether a version may be configured in the OS
	// image catalog. It may accept more than versions() (e.g. pinned point
	// releases of a supported series).
	supports_version(version string) bool
	// assets_ready reports whether kernel/rootfs assets are locally available.
	assets_ready(req core.BootRequest) bool
	// install_script returns the iPXE script that boots the installer.
	install_script(req core.BootRequest) !string
	// user_data returns the autoinstall/cloud-init user-data (seed file).
	user_data(req core.BootRequest) !string
	// meta_data returns the cloud-init meta-data (seed file).
	meta_data(req core.BootRequest) !string
}

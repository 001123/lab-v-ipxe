module store

import json2

// OsImage is one entry of the installable-image catalog configured in
// Settings: which OS/version to boot plus its installer source. Machines
// inherit nfs_root from the row matching their (os_name, os_version) unless
// they define their own override.
pub struct OsImage {
pub mut:
	os_name    string
	version    string
	nfs_root   string
	is_default bool
}

// os_images returns the catalog; a missing, empty or invalid JSON value
// yields an empty list (the caller decides how to react).
pub fn (s &Store) os_images() []OsImage {
	raw := s.setting(setting_os_images) or { return [] }
	if raw.trim_space() == '' {
		return []
	}
	return json2.decode[[]OsImage](raw) or { [] }
}

pub fn (s &Store) set_os_images(images []OsImage) ! {
	s.set_setting(setting_os_images, json2.encode(images))!
}

pub fn (s &Store) os_image_for(os_name string, version string) ?OsImage {
	for img in s.os_images() {
		if img.os_name == os_name && img.version == version {
			return img
		}
	}
	return none
}

// default_os_image is the row flagged as default, falling back to the first
// row when no flag is set.
pub fn (s &Store) default_os_image() ?OsImage {
	images := s.os_images()
	if images.len == 0 {
		return none
	}
	for img in images {
		if img.is_default {
			return img
		}
	}
	return images[0]
}

// seed_os_images writes the initial catalog on first start: it migrates the
// legacy nfs_root_default/ubuntu_version settings keys when present (those
// keys were ubuntu-only), otherwise falls back to the given config defaults.
// Returns true when a seed was written.
pub fn (s &Store) seed_os_images(fallback_nfs_root string, fallback_version string) !bool {
	if s.os_images().len > 0 {
		return false
	}
	nfs_root := s.setting_or(setting_nfs_root, fallback_nfs_root)
	version := s.setting_or(setting_ubuntu_version, fallback_version)
	s.set_os_images([
		OsImage{
			os_name:    'ubuntu'
			version:    version
			nfs_root:   nfs_root
			is_default: true
		},
	])!
	s.delete_setting(setting_nfs_root)!
	s.delete_setting(setting_ubuntu_version)!
	eprintln('[store] seeded os image catalog: ubuntu ${version} (${nfs_root})')
	return true
}

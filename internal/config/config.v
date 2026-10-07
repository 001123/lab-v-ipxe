module config

import dirs
import os
import strconv

pub const app_name = 'lab-v-ipxe'
pub const version = '0.1.0'

pub const default_admin_email = 'admin@ipxe.local'
pub const default_admin_password = 'admin@pwd'
pub const default_nfs_root = '192.168.250.4:/srv/nfs/ubuntu-26.04.1'
pub const default_ubuntu_version = '26.04.1'

pub struct Config {
pub mut:
	port              int
	data_dir          string
	base_url          string // empty = derive from request Host header
	admin_email       string
	admin_password    string
	ubuntu_iso        string // local ISO override (LAB_V_IPXE_UBUNTU_ISO)
	ubuntu_assets_dir string // dir containing vmlinuz+initrd (LAB_V_IPXE_UBUNTU_ASSETS_DIR)
	keep_iso          bool
}

pub fn load() Config {
	return Config{
		port:              env_int('LAB_V_IPXE_PORT', 8080)
		data_dir:          dirs.resolve_data_dir()
		base_url:          env_str('LAB_V_IPXE_BASE_URL', '')
		admin_email:       env_str('LAB_V_IPXE_ADMIN_EMAIL', default_admin_email)
		admin_password:    env_str('LAB_V_IPXE_ADMIN_PASSWORD', default_admin_password)
		ubuntu_iso:        env_str('LAB_V_IPXE_UBUNTU_ISO', '')
		ubuntu_assets_dir: env_str('LAB_V_IPXE_UBUNTU_ASSETS_DIR', '')
		keep_iso:          env_bool('LAB_V_IPXE_KEEP_ISO', false)
	}
}

fn env_str(key string, fallback string) string {
	v := os.getenv_opt(key) or { return fallback }
	if v == '' {
		return fallback
	}
	return v
}

fn env_int(key string, fallback int) int {
	v := os.getenv_opt(key) or { return fallback }
	return strconv.atoi(v) or { fallback }
}

fn env_bool(key string, fallback bool) bool {
	v := os.getenv_opt(key) or { return fallback }
	return v.to_lower() in ['1', 'true', 'yes', 'on']
}

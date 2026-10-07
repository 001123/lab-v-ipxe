module dirs

import os

const app_dir_name = 'lab-v-ipxe'

// resolve_data_dir returns the runtime data directory:
// env override > prod user-data dir > dev ./tmp
pub fn resolve_data_dir() string {
	if v := os.getenv_opt('LAB_V_IPXE_DATA_DIR') {
		if v != '' {
			return os.abs_path(v)
		}
	}
	$if prod {
		return os.join_path(os.data_dir(), app_dir_name)
	} $else {
		return os.join_path(os.getwd(), 'tmp')
	}
}

pub fn ensure(path string) ! {
	if !os.exists(path) {
		os.mkdir_all(path)!
	}
}

pub fn db_path(data_dir string) string {
	return os.join_path(data_dir, 'lab-v-ipxe.db')
}

pub fn assets_dir(data_dir string) string {
	return os.join_path(data_dir, 'assets')
}

pub fn cache_dir(data_dir string) string {
	return os.join_path(data_dir, 'cache')
}

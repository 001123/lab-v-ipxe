module server

import internal.config
import json2
import internal.providers.ubuntu
import internal.store
import veb

pub struct AssetStatusDto {
pub:
	os_name     string
	phase       string
	version     string
	message     string
	percent     int
	bytes_done  i64
	bytes_total i64
	source      string
}

pub struct ProviderDto {
pub:
	name         string
	display_name string
	versions     []string
}

pub struct SettingsRes {
pub:
	data_dir          string
	db_path           string
	base_url_override string
	ssh_keys_default  string
	os_images         []store.OsImage
	providers         []ProviderDto
	extractors        []string
	assets            []AssetStatusDto
	system            SystemInfo
}

pub struct SettingsPayload {
pub:
	ssh_keys_default  string
	base_url_override string
	os_images         []store.OsImage
}

pub struct AssetFetchPayload {
pub:
	os_name string
	version string
}

fn (mut app App) build_settings_res() SettingsRes {
	images := app.st.os_images()
	mut providers := []ProviderDto{}
	for _, p in app.os_providers {
		providers << ProviderDto{
			name:         p.name()
			display_name: p.display_name()
			versions:     p.versions()
		}
	}
	providers.sort(a.name < b.name)
	mut assets := []AssetStatusDto{}
	for img in images {
		// TODO(multi-os): only ubuntu has a file-backed asset pipeline today
		if img.os_name == 'ubuntu' {
			app.assets.refresh_status(img.version)
			st := app.assets.status_snapshot(img.version)
			assets << AssetStatusDto{
				os_name:     img.os_name
				phase:       st.phase.str()
				version:     st.version
				message:     st.message
				percent:     st.percent
				bytes_done:  st.bytes_done
				bytes_total: st.bytes_total
				source:      st.source
			}
		}
	}
	return SettingsRes{
		data_dir:          app.cfg.data_dir
		db_path:           config.db_path(app.cfg.data_dir)
		base_url_override: app.st.setting_or(store.setting_base_url, app.cfg.base_url)
		ssh_keys_default:  app.st.setting_or(store.setting_ssh_keys, '')
		os_images:         images
		providers:         providers
		extractors:        ubuntu.available_extractors()
		assets:            assets
		system:            app.get_system_info()
	}
}

// validate_nfs_root checks a host:/path NFS export string. IPv6 hosts and
// whitespace/control characters are rejected: the value goes on a kernel
// cmdline and into the iPXE script verbatim.
fn validate_nfs_root(raw string) !string {
	v := raw.trim_space()
	if v == '' {
		return error('nfs_root is required (expected host:/path)')
	}
	for c in v {
		if c <= ` ` || c == 0x7f {
			return error('invalid nfs_root "${raw}" (expected host:/path without spaces or control characters)')
		}
	}
	colon := v.index(':') or { return error('invalid nfs_root "${raw}" (expected host:/path)') }
	host := v[..colon]
	path := v[colon + 1..]
	if host == '' || host.contains(':') || !path.starts_with('/') {
		return error('invalid nfs_root "${raw}" (expected host:/path)')
	}
	return v
}

// validate_os_images normalizes a submitted catalog: known provider,
// supported version, valid host:/path export, no duplicate (os, version) and
// exactly one default row. Nothing is written unless the whole list is valid.
fn validate_os_images(app &App, rows []store.OsImage) ![]store.OsImage {
	mut clean := []store.OsImage{cap: rows.len}
	mut seen := map[string]bool{}
	mut default_idx := -1
	for r in rows {
		os_name := r.os_name.trim_space()
		p := app.provider_for(os_name) or { return error('unknown os "${r.os_name}"') }
		version := r.version.trim_space()
		if !p.supports_version(version) {
			return error('os "${os_name}" has no version "${version}" (available: ${p.versions().join(', ')}, plus point releases of those series)')
		}
		key := '${os_name}/${version}'
		if seen[key] {
			return error('duplicate os image "${key}"')
		}
		seen[key] = true
		nfs_root := validate_nfs_root(r.nfs_root)!
		is_default := r.is_default && default_idx == -1
		if is_default {
			default_idx = clean.len
		}
		clean << store.OsImage{
			os_name:    os_name
			version:    version
			nfs_root:   nfs_root
			is_default: is_default
		}
	}
	if default_idx == -1 {
		clean[0].is_default = true
	}
	return clean
}

@['/api/settings'; get]
pub fn (mut app App) settings_get(mut ctx Context) veb.Result {
	return ctx.json(app.build_settings_res())
}

@['/api/settings'; put]
pub fn (mut app App) settings_put(mut ctx Context) veb.Result {
	payload := json2.decode[SettingsPayload](ctx.req.data) or {
		return bad_request(mut ctx, 'invalid json body')
	}
	mut images := []store.OsImage{}
	if payload.os_images.len > 0 {
		images = validate_os_images(app, payload.os_images) or {
			return bad_request(mut ctx, err.msg())
		}
	}
	base_url := payload.base_url_override.trim_space()
	if base_url != '' {
		valid := base_url_from(base_url) or { return bad_request(mut ctx, err.msg()) }
		app.st.set_setting(store.setting_base_url, valid) or {
			return server_error(mut ctx, err.msg())
		}
	}
	ssh := payload.ssh_keys_default.trim_space()
	if ssh == 'auto' {
		app.st.set_setting(store.setting_ssh_keys, '') or {
			return server_error(mut ctx, err.msg())
		}
	} else if ssh != '' {
		valid := ssh_keys_from(ssh) or { return bad_request(mut ctx, err.msg()) }
		app.st.set_setting(store.setting_ssh_keys, valid) or {
			return server_error(mut ctx, err.msg())
		}
	}
	// empty os_images keeps the current catalog (partial-update semantics)
	if payload.os_images.len > 0 {
		app.st.set_os_images(images) or {
			return server_error(mut ctx, err.msg())
		}
	}
	return ctx.json(app.build_settings_res())
}

@['/api/assets/fetch'; post]
pub fn (mut app App) assets_fetch(mut ctx Context) veb.Result {
	mut payload := AssetFetchPayload{}
	if ctx.req.data.trim_space() != '' {
		payload = json2.decode[AssetFetchPayload](ctx.req.data) or {
			return bad_request(mut ctx, 'invalid json body')
		}
	}
	os_name := payload.os_name.trim_space()
	version := payload.version.trim_space()
	if os_name == '' && version == '' {
		for img in app.st.os_images() {
			app.start_assets_fetch(img.os_name, img.version, true)
		}
	} else if os_name != '' && version != '' {
		_ := app.st.os_image_for(os_name, version) or {
			return bad_request(mut ctx, 'os image "${os_name} ${version}" is not in the catalog')
		}
		app.start_assets_fetch(os_name, version, true)
	} else {
		return bad_request(mut ctx, 'provide both os_name and version, or neither')
	}
	return ctx.json(app.build_settings_res())
}

@['/api/system/info'; get]
pub fn (app &App) system_info_endpoint(mut ctx Context) veb.Result {
	return ctx.json(app.get_system_info())
}


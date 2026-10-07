module server

import config
import dirs
import json2
import providers.ubuntu
import store
import veb

pub struct AssetStatusDto {
pub:
	phase       string
	version     string
	message     string
	percent     int
	bytes_done  i64
	bytes_total i64
	source      string
}

pub struct SettingsRes {
pub:
	data_dir          string
	db_path           string
	base_url_override string
	nfs_root_default  string
	ubuntu_version    string
	extractors        []string
	assets            AssetStatusDto
}

pub struct SettingsPayload {
pub:
	nfs_root_default  string
	ubuntu_version    string
	base_url_override string
}

fn (app &App) ubuntu_version() string {
	return app.st.setting_or(store.setting_ubuntu_version, config.default_ubuntu_version)
}

fn (mut app App) build_settings_res() SettingsRes {
	version := app.ubuntu_version()
	app.assets.refresh_status(version)
	st := app.assets.status_snapshot()
	return SettingsRes{
		data_dir:          app.cfg.data_dir
		db_path:           dirs.db_path(app.cfg.data_dir)
		base_url_override: app.st.setting_or(store.setting_base_url, app.cfg.base_url)
		nfs_root_default:  app.st.setting_or(store.setting_nfs_root, config.default_nfs_root)
		ubuntu_version:    version
		extractors:        ubuntu.available_extractors()
		assets:            AssetStatusDto{
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

@['/api/settings'; get]
pub fn (mut app App) settings_get(mut ctx Context) veb.Result {
	return ctx.json(app.build_settings_res())
}

@['/api/settings'; put]
pub fn (mut app App) settings_put(mut ctx Context) veb.Result {
	payload := json2.decode[SettingsPayload](ctx.req.data) or {
		return bad_request(mut ctx, 'invalid json body')
	}
	nfs_root := payload.nfs_root_default.trim_space()
	if nfs_root != '' {
		app.st.set_setting(store.setting_nfs_root, nfs_root) or {
			return server_error(mut ctx, err.msg())
		}
	}
	version := payload.ubuntu_version.trim_space()
	if version != '' {
		app.st.set_setting(store.setting_ubuntu_version, version) or {
			return server_error(mut ctx, err.msg())
		}
	}
	base_url := payload.base_url_override.trim_space()
	if base_url != '' {
		app.st.set_setting(store.setting_base_url, base_url) or {
			return server_error(mut ctx, err.msg())
		}
	}
	return ctx.json(app.build_settings_res())
}

@['/api/assets/fetch'; post]
pub fn (mut app App) assets_fetch(mut ctx Context) veb.Result {
	app.assets.ensure_assets(app.ubuntu_version())
	return ctx.json(app.build_settings_res())
}

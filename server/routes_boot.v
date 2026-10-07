module server

import config
import core
import macutils
import providers
import store
import veb

// base_url resolves the externally reachable URL for building boot scripts:
// settings override > env config > the Host header of the incoming request.
fn (app &App) base_url(ctx &Context) string {
	override := app.st.setting_or(store.setting_base_url, app.cfg.base_url)
	if override != '' {
		return override
	}
	host := ctx.req.header.get(.host) or { '127.0.0.1:${app.cfg.port}' }
	return 'http://${host}'
}

fn (app &App) provider_for(name string) ?providers.OSProvider {
	p := app.os_providers[name] or { return none }
	return p
}

fn (app &App) request_for(m &store.Machine, base_url string) core.BootRequest {
	nfs_root := if m.nfs_root != '' {
		m.nfs_root
	} else {
		app.st.setting_or(store.setting_nfs_root, config.default_nfs_root)
	}
	return core.BootRequest{
		base_url:       base_url
		mac:            m.mac
		mac_key:        m.mac_key
		hostname:       m.hostname
		username:       m.username
		password_hash:  m.password_hash
		ssh_keys:       m.ssh_keys
		nfs_root:       nfs_root
		os_name:        m.os_name
		os_version:     m.os_version
		arch:           'amd64'
		storage_layout: m.storage_layout
		install_count:  m.install_count
		boot_mode:      m.boot_mode
	}
}

@['/boot.ipxe'; get]
pub fn (mut app App) boot_ipxe(mut ctx Context) veb.Result {
	mac_raw := ctx.query['mac'].trim_space()
	if mac_raw == '' {
		return ctx.text(core.error_script('missing mac query parameter'))
	}
	mac := macutils.normalize(mac_raw) or {
		return ctx.text(core.error_script('invalid mac "${mac_raw}"'))
	}
	mac_key := macutils.key(mac)
	base_url := app.base_url(&ctx)
	mut m := app.st.machine_by_mac_key(mac_key) or {
		mut created := store.Machine{
			mac:          mac
			mac_key:      mac_key
			auto_created: true
		}
		app.st.machine_save(mut created) or {
			// lost a race with a concurrent first boot; fetch the stored row
			app.st.machine_by_mac_key(mac_key) or {
				return ctx.text(core.error_script('database error'))
			}
		}
		created
	}
	req := app.request_for(m, base_url)
	provider := app.provider_for(m.os_name) or {
		return ctx.text(core.error_script('no provider for os "${m.os_name}"'))
	}
	return match core.boot_action(m.status, provider.assets_ready(req)) {
		.wait_approval {
			ctx.text(core.wait_script(base_url, mac, 'this machine is waiting for approval.'))
		}
		.wait_assets {
			app.start_assets_fetch()
			ctx.text(core.wait_script(base_url, mac, 'installer assets are being prepared...'))
		}
		.install {
			script := provider.install_script(req) or {
				return ctx.text(core.error_script(err.msg()))
			}
			if core.transition_after_boot_script(mut m) {
				app.st.machine_save(mut m) or { eprintln('[boot] save transition failed: ${err.msg()}') }
			}
			ctx.text(script)
		}
		.sanboot {
			ctx.text(core.sanboot_script())
		}
	}
}

fn serve_seed_file(app &App, mut ctx Context, os_name string, version string, mac_raw string,
	file string) veb.Result {
	mac := macutils.normalize(mac_raw) or { return seed_not_found(mut ctx) }
	m := app.st.machine_by_mac_key(macutils.key(mac)) or { return seed_not_found(mut ctx) }
	if m.status !in [.approved, .installing] {
		return seed_not_found(mut ctx)
	}
	if version != m.os_version {
		return seed_not_found(mut ctx)
	}
	provider := app.provider_for(os_name) or { return seed_not_found(mut ctx) }
	if provider.name() != m.os_name {
		return seed_not_found(mut ctx)
	}
	base_url := app.base_url(&ctx)
	req := app.request_for(m, base_url)
	mut body := ''
	if file == 'user-data' {
		body = provider.user_data(req) or { return seed_not_found(mut ctx) }
	} else if file == 'meta-data' {
		body = provider.meta_data(req) or { return seed_not_found(mut ctx) }
	} else {
		body = '#cloud-config\n'
	}
	return ctx.text(body)
}

fn seed_not_found(mut ctx Context) veb.Result {
	ctx.res.set_status(.not_found)
	return ctx.text('not found')
}

@['/os/:os_name/:version/:mac/user-data'; get]
pub fn (mut app App) os_user_data(mut ctx Context, os_name string, version string, mac string) veb.Result {
	return serve_seed_file(app, mut ctx, os_name, version, mac, 'user-data')
}

@['/os/:os_name/:version/:mac/meta-data'; get]
pub fn (mut app App) os_meta_data(mut ctx Context, os_name string, version string, mac string) veb.Result {
	return serve_seed_file(app, mut ctx, os_name, version, mac, 'meta-data')
}

@['/os/:os_name/:version/:mac/vendor-data'; get]
pub fn (mut app App) os_vendor_data(mut ctx Context, os_name string, version string, mac string) veb.Result {
	return serve_seed_file(app, mut ctx, os_name, version, mac, 'vendor-data')
}

@['/assets/:os_name/:version/:file'; get]
pub fn (mut app App) assets_get(mut ctx Context, os_name string, version string, file string) veb.Result {
	if os_name != 'ubuntu' || file !in ['vmlinuz', 'initrd'] {
		return seed_not_found(mut ctx)
	}
	path := app.assets.path_for(version, file) or {
		return seed_not_found(mut ctx)
	}
	// kernel/initrd have no extension: register the empty extension
	ctx.custom_mime_types[''] = 'application/octet-stream'
	return ctx.file(path)
}

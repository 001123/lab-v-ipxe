module server

import internal.config
import db.sqlite
import internal.providers
import internal.providers.ubuntu
import internal.store
import time
import veb
import veb.auth

pub struct Context {
	veb.Context
pub mut:
	user_id int
}

pub struct App {
	veb.Middleware[Context]
pub mut:
	cfg          config.Config
	st           &store.Store
	auth         auth.Auth[sqlite.DB]
	assets       &ubuntu.AssetManager
	os_providers map[string]providers.OSProvider
	start_time   i64
	// embedded SPA, materialized once at startup (see routes_spa.v)
	spa_files   map[string]string
	spa_enabled bool
}

pub fn new_app(cfg config.Config, st &store.Store) &App {
	// migrate legacy settings (nfs_root_default/ubuntu_version) into the
	// os_images catalog once, when the catalog is still empty
	st.seed_os_images(config.default_nfs_root, config.default_ubuntu_version) or {
		eprintln('[app] os image catalog seed failed: ${err.msg()}')
	}
	assets := ubuntu.new_assets(config.assets_dir(cfg.data_dir), cfg.ubuntu_assets_dir, cfg.ubuntu_iso,
		cfg.keep_iso)
	mut app := &App{
		cfg:          cfg
		st:           st
		assets:       assets
		start_time:   time.now().unix()
		os_providers: {
			'ubuntu': providers.OSProvider(ubuntu.new(assets))
		}
	}
	app.auth = auth.new(st.db)
	app.load_spa()
	app.Middleware.use(handler: log_requests)
	app.Middleware.route_use('/api/:path...',
		handler: fn [app] (mut ctx Context) bool {
			return app.require_auth(mut ctx)
		}
	)
	// Compression must be last (it runs "after" the handlers).
	app.Middleware.use(veb.encode_auto[Context]())
	return app
}

// start_assets_fetch kicks off asset preparation in the background when a
// machine wants to install but the kernel/initrd are not available yet.
// `force` is for explicit operator actions, which bypass the automatic
// retry backoff. Only ubuntu has a file-backed asset pipeline today; route
// this through OSProvider once a second file-boot provider exists.
fn (mut app App) start_assets_fetch(os_name string, version string, force bool) {
	if os_name == 'ubuntu' {
		if force {
			app.assets.fetch_assets_now(version)
		} else {
			app.assets.ensure_assets(version)
		}
	}
}

struct HealthRes {
	status  string
	name    string
	version string
	db      string
}

@['/healthz'; get]
pub fn (mut app App) healthz(mut ctx Context) veb.Result {
	mut db_status := 'ok'
	app.st.ping() or { db_status = 'error' }
	return ctx.json(HealthRes{
		status:  'ok'
		name:    config.app_name
		version: config.version
		db:      db_status
	})
}

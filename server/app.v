module server

import config
import db.sqlite
import dirs
import providers
import providers.ubuntu
import store
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
}

pub fn new_app(cfg config.Config, st &store.Store) &App {
	assets := ubuntu.new_assets(dirs.assets_dir(cfg.data_dir), cfg.ubuntu_assets_dir, cfg.ubuntu_iso,
		cfg.keep_iso)
	mut app := &App{
		cfg:          cfg
		st:           st
		assets:       assets
		os_providers: {
			'ubuntu': providers.OSProvider(ubuntu.new(assets))
		}
	}
	app.auth = auth.new(st.db)
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
fn (mut app App) start_assets_fetch() {
	app.assets.ensure_assets(app.ubuntu_version())
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

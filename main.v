module main

import internal.config
import internal.server
import internal.store
import veb

fn main() {
	cfg := config.load()
	config.ensure(cfg.data_dir)!
	mut st := store.open(config.db_path(cfg.data_dir))!
	st.migrate()!
	st.seed_admin(cfg.admin_email, cfg.admin_password)!
	println('${config.app_name} ${config.version}')
	println('data dir : ${cfg.data_dir}')
	println('listening: http://0.0.0.0:${cfg.port}')
	mut app := server.new_app(cfg, st)
	veb.run[server.App, server.Context](mut app, cfg.port)
}

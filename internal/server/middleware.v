module server

pub fn log_requests(mut ctx Context) bool {
	eprintln('${ctx.req.method} ${ctx.req.url}')
	return true
}

const auth_allowlist = ['/api/auth/login', '/api/machines/installed']

// veb.auth runs raw ORM queries on the shared sqlite connection without
// locking. veb serves requests from multiple threads, so those queries can
// race with the locked Store calls and crash libsqlite3 (seen as SIGSEGV in
// sqlite3_prepare/tokenExpr on macOS). Serialize them with the store's mutex;
// never call Store methods from inside these wrappers (the mutex is not
// re-entrant).
fn (app &App) auth_user_id(token string) ?int {
	app.st.mu.lock()
	defer {
		app.st.mu.unlock()
	}
	tok := app.auth.find_token(token) or { return none }
	return tok.user_id
}

fn (mut app App) auth_add_token(user_id int) !string {
	app.st.mu.lock()
	defer {
		app.st.mu.unlock()
	}
	return app.auth.add_token(user_id)
}

pub fn (app &App) require_auth(mut ctx Context) bool {
	path := ctx.req.url.all_before('?')
	if path in auth_allowlist {
		return true
	}
	token := bearer_token(&ctx)
	if token == '' {
		return unauthorized(mut ctx)
	}
	ctx.user_id = app.auth_user_id(token) or { return unauthorized(mut ctx) }
	return true
}

fn unauthorized(mut ctx Context) bool {
	ctx.res.set_status(.unauthorized)
	ctx.text('{"message":"unauthorized"}')
	return false
}

fn bearer_token(ctx &Context) string {
	hdr := ctx.req.header.get(.authorization) or { return '' }
	if !hdr.starts_with('Bearer ') {
		return ''
	}
	return hdr['Bearer '.len..].trim_space()
}

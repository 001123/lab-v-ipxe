module server

pub fn log_requests(mut ctx Context) bool {
	eprintln('${ctx.req.method} ${ctx.req.url}')
	return true
}

const auth_allowlist = ['/api/auth/login', '/api/machines/installed']

pub fn (app &App) require_auth(mut ctx Context) bool {
	path := ctx.req.url.all_before('?')
	if path in auth_allowlist {
		return true
	}
	token := bearer_token(&ctx)
	if token == '' {
		return unauthorized(mut ctx)
	}
	tok := app.auth.find_token(token) or { return unauthorized(mut ctx) }
	ctx.user_id = tok.user_id
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

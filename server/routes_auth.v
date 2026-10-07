module server

import json2
import store
import veb

@['/api/auth/login'; post]
pub fn (mut app App) login(mut ctx Context) veb.Result {
	payload := json2.decode[LoginPayload](ctx.req.data) or {
		ctx.res.set_status(.bad_request)
		return ctx.json(MessageRes{
			message: 'invalid json body'
		})
	}
	user := app.st.user_by_email(payload.email) or {
		ctx.res.set_status(.unauthorized)
		return ctx.json(MessageRes{
			message: 'invalid credentials'
		})
	}
	if !store.verify_password(user.password_hash, payload.password) {
		ctx.res.set_status(.unauthorized)
		return ctx.json(MessageRes{
			message: 'invalid credentials'
		})
	}
	token := app.auth.add_token(user.id) or {
		ctx.res.set_status(.internal_server_error)
		return ctx.json(MessageRes{
			message: 'could not create session token'
		})
	}
	return ctx.json(LoginRes{
		token: token
		user:  UserDto{
			email: user.email
		}
	})
}

@['/api/auth/logout'; post]
pub fn (mut app App) logout(mut ctx Context) veb.Result {
	token := bearer_token(&ctx)
	if token != '' {
		app.st.delete_token(token) or { eprintln('[auth] logout delete_token: ${err.msg()}') }
	}
	return ctx.json(OkRes{
		ok: true
	})
}

@['/api/auth/me'; get]
pub fn (mut app App) me(mut ctx Context) veb.Result {
	user := app.st.user_by_id(ctx.user_id) or {
		ctx.res.set_status(.unauthorized)
		return ctx.json(MessageRes{
			message: 'unauthorized'
		})
	}
	return ctx.json(UserDto{
		email: user.email
	})
}

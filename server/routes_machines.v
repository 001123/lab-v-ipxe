module server

import json2
import macutils
import sha512crypt
import store
import veb

fn bad_request(mut ctx Context, msg string) veb.Result {
	ctx.res.set_status(.bad_request)
	return ctx.json(MessageRes{
		message: msg
	})
}

fn not_found(mut ctx Context, msg string) veb.Result {
	ctx.res.set_status(.not_found)
	return ctx.json(MessageRes{
		message: msg
	})
}

fn conflict(mut ctx Context, msg string) veb.Result {
	ctx.res.set_status(.conflict)
	return ctx.json(MessageRes{
		message: msg
	})
}

fn server_error(mut ctx Context, msg string) veb.Result {
	eprintln('[server] internal error: ${msg}')
	ctx.res.set_status(.internal_server_error)
	return ctx.json(MessageRes{
		message: 'internal server error'
	})
}

// apply_payload merges a payload into a machine: provided (non-empty) fields
// replace the current values, empty fields keep them. mac is required on create.
fn apply_payload(mut m store.Machine, p MachinePayload, is_create bool) ! {
	if p.mac.trim_space() != '' {
		normalized := macutils.normalize(p.mac)!
		m.mac = normalized
		m.mac_key = macutils.key(normalized)
	} else if is_create {
		return error('mac is required')
	}
	h := p.hostname.trim_space()
	if h != '' {
		m.hostname = h
	}
	u := p.username.trim_space()
	if u != '' {
		m.username = u
	}
	if p.password != '' {
		m.password_hash = sha512crypt.hash(p.password, sha512crypt.generate_salt(),
			sha512crypt.default_rounds)
	}
	k := p.ssh_keys.trim_space()
	if k != '' {
		m.ssh_keys = k
	}
	r := p.nfs_root.trim_space()
	if r != '' {
		m.nfs_root = r
	}
	n := p.notes.trim_space()
	if n != '' {
		m.notes = n
	}
	o := p.os_name.trim_space()
	if o != '' {
		m.os_name = o
	}
	v := p.os_version.trim_space()
	if v != '' {
		m.os_version = v
	}
	if p.boot_mode.trim_space() != '' {
		m.boot_mode = boot_mode_from(p.boot_mode) or {
			return error('invalid boot_mode "${p.boot_mode}" (expected nfs or http)')
		}
	}
	if p.storage_layout.trim_space() != '' {
		m.storage_layout = storage_layout_from(p.storage_layout) or {
			return error('invalid storage_layout "${p.storage_layout}" (expected zfs, direct or lvm)')
		}
	}
}

@['/api/machines'; get]
pub fn (mut app App) machines_list(mut ctx Context) veb.Result {
	filter := ctx.query['status']
	mut list := []store.Machine{}
	if filter != '' {
		status := status_filter_from(filter) or {
			return bad_request(mut ctx, 'invalid status filter "${filter}"')
		}
		list = app.st.machines_list(status)
	} else {
		list = app.st.machines_list(none)
	}
	return ctx.json(list.map(machine_to_dto(it)))
}

@['/api/machines'; post]
pub fn (mut app App) machines_create(mut ctx Context) veb.Result {
	payload := json2.decode[MachinePayload](ctx.req.data) or {
		return bad_request(mut ctx, 'invalid json body')
	}
	mut m := store.Machine{}
	apply_payload(mut m, payload, true) or { return bad_request(mut ctx, err.msg()) }
	if _ := app.st.machine_by_mac_key(m.mac_key) {
		return conflict(mut ctx, 'machine with MAC ${m.mac} already exists')
	}
	app.st.machine_save(mut m) or { return server_error(mut ctx, err.msg()) }
	return ctx.json(machine_to_dto(m))
}

@['/api/machines/:id'; get]
pub fn (mut app App) machines_get(mut ctx Context, id string) veb.Result {
	m := app.st.machine_by_id(id.int()) or { return not_found(mut ctx, 'machine not found') }
	return ctx.json(machine_to_dto(m))
}

@['/api/machines/:id'; put]
pub fn (mut app App) machines_update(mut ctx Context, id string) veb.Result {
	payload := json2.decode[MachinePayload](ctx.req.data) or {
		return bad_request(mut ctx, 'invalid json body')
	}
	mut m := app.st.machine_by_id(id.int()) or { return not_found(mut ctx, 'machine not found') }
	apply_payload(mut m, payload, false) or { return bad_request(mut ctx, err.msg()) }
	if existing := app.st.machine_by_mac_key(m.mac_key) {
		if existing.id != m.id {
			return conflict(mut ctx, 'machine with MAC ${m.mac} already exists')
		}
	}
	app.st.machine_save(mut m) or { return server_error(mut ctx, err.msg()) }
	return ctx.json(machine_to_dto(m))
}

@['/api/machines/:id'; delete]
pub fn (mut app App) machines_delete(mut ctx Context, id string) veb.Result {
	m := app.st.machine_by_id(id.int()) or { return not_found(mut ctx, 'machine not found') }
	app.st.machine_delete(m.id) or { return server_error(mut ctx, err.msg()) }
	return ctx.json(OkRes{
		ok: true
	})
}

@['/api/machines/:id/approve'; post]
pub fn (mut app App) machines_approve(mut ctx Context, id string) veb.Result {
	payload := json2.decode[MachinePayload](ctx.req.data) or {
		return bad_request(mut ctx, 'invalid json body')
	}
	mut m := app.st.machine_by_id(id.int()) or { return not_found(mut ctx, 'machine not found') }
	apply_payload(mut m, payload, false) or { return bad_request(mut ctx, err.msg()) }
	if m.hostname.trim_space() == '' {
		return bad_request(mut ctx, 'hostname is required to approve a machine')
	}
	m.status = .approved
	m.approved_at = store.now_unix()
	app.st.machine_save(mut m) or { return server_error(mut ctx, err.msg()) }
	return ctx.json(machine_to_dto(m))
}

@['/api/machines/:id/reinstall'; post]
pub fn (mut app App) machines_reinstall(mut ctx Context, id string) veb.Result {
	mut m := app.st.machine_by_id(id.int()) or { return not_found(mut ctx, 'machine not found') }
	m.status = .approved
	m.install_count += 1
	m.approved_at = store.now_unix()
	m.installed_at = 0
	app.st.machine_save(mut m) or { return server_error(mut ctx, err.msg()) }
	return ctx.json(machine_to_dto(m))
}

@['/api/machines/:id/mark-installed'; post]
pub fn (mut app App) machines_mark_installed(mut ctx Context, id string) veb.Result {
	mut m := app.st.machine_by_id(id.int()) or { return not_found(mut ctx, 'machine not found') }
	m.status = .installed
	m.installed_at = store.now_unix()
	m.last_seen_at = store.now_unix()
	app.st.machine_save(mut m) or { return server_error(mut ctx, err.msg()) }
	return ctx.json(machine_to_dto(m))
}

// machines_phone_home is called from the autoinstall late-commands (public).
@['/api/machines/installed'; post]
pub fn (mut app App) machines_phone_home(mut ctx Context) veb.Result {
	mac_raw := ctx.form['mac']
	if mac_raw.trim_space() == '' {
		return bad_request(mut ctx, 'mac is required')
	}
	mac := macutils.normalize(mac_raw) or { return bad_request(mut ctx, 'invalid MAC address') }
	mut m := app.st.machine_by_mac_key(macutils.key(mac)) or {
		return not_found(mut ctx, 'unknown MAC ${mac}')
	}
	hostname := ctx.form['hostname'].trim_space()
	if hostname != '' {
		m.hostname = hostname
	}
	m.status = .installed
	m.installed_at = store.now_unix()
	m.last_seen_at = store.now_unix()
	app.st.machine_save(mut m) or { return server_error(mut ctx, err.msg()) }
	return ctx.json(OkRes{
		ok: true
	})
}

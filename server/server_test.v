module server

import config
import json2
import net.http
import os
import store
import time
import veb

const test_port = 13081
const test_base = 'http://127.0.0.1:${test_port}'

fn h_auth(token string) http.Header {
	return http.new_header_from_map({
		http.CommonHeader.authorization: 'Bearer ${token}'
	})
}

fn h_json_auth(token string) http.Header {
	return http.new_header_from_map({
		http.CommonHeader.content_type:  'application/json'
		http.CommonHeader.authorization: 'Bearer ${token}'
	})
}

fn test_full_api_flow() {
	test_dir := os.join_path(os.vtmp_dir(), 'labvipxe_test_${os.getpid()}')
	os.mkdir_all(test_dir)!
	db_path := os.join_path(test_dir, 'test.db')
	mut st := store.open(db_path)!
	st.migrate()!
	st.seed_admin('admin@ipxe.local', 'admin@pwd')!
	mut app := new_app(config.load(), st)
	spawn veb.run_at[App, Context](mut app, port: test_port, family: .ip)

	mut ready := false
	for _ in 0 .. 60 {
		if _ := http.fetch(url: '${test_base}/healthz') {
			ready = true
			break
		}
		time.sleep(100 * time.millisecond)
	}
	assert ready, 'server did not start'

	// unauthenticated access is rejected
	res := http.fetch(url: '${test_base}/api/machines')!
	assert res.status_code == 401

	// wrong password
	res2 := http.fetch(
		method: .post
		url:    '${test_base}/api/auth/login'
		data:   '{"email":"admin@ipxe.local","password":"nope"}'
	)!
	assert res2.status_code == 401

	// login
	res3 := http.fetch(
		method: .post
		url:    '${test_base}/api/auth/login'
		data:   '{"email":"admin@ipxe.local","password":"admin@pwd"}'
	)!
	assert res3.status_code == 200
	token := json2.decode[LoginRes](res3.body)!.token
	assert token != ''

	// empty machine list
	res4 := http.fetch(url: '${test_base}/api/machines', header: h_auth(token))!
	assert res4.status_code == 200
	assert json2.decode[[]MachineDto](res4.body)!.len == 0

	// create with a lowercase MAC: it must come back UPPERCASE
	res5 := http.fetch(
		method: .post
		url:    '${test_base}/api/machines'
		header: h_json_auth(token)
		data:   '{"mac":"bc:24:11:00:24:99","hostname":"vm-test","password":"secret123","storage_layout":"zfs","boot_mode":"nfs"}'
	)!
	assert res5.status_code == 200
	created := json2.decode[MachineDto](res5.body)!
	assert created.mac == 'BC:24:11:00:24:99'
	assert created.status == 'pending'
	assert created.storage_layout == 'zfs'
	assert created.has_password

	// duplicate MAC (different spelling) -> 409
	res6 := http.fetch(
		method: .post
		url:    '${test_base}/api/machines'
		header: h_json_auth(token)
		data:   '{"mac":"BC-24-11-00-24-99"}'
	)!
	assert res6.status_code == 409

	// invalid MAC -> 400
	res7 := http.fetch(
		method: .post
		url:    '${test_base}/api/machines'
		header: h_json_auth(token)
		data:   '{"mac":"zz:zz"}'
	)!
	assert res7.status_code == 400

	// update only provided fields; the password hash must survive
	res8 := http.fetch(
		method: .put
		url:    '${test_base}/api/machines/${created.id}'
		header: h_json_auth(token)
		data:   '{"hostname":"renamed","username":"timi","ssh_keys":"ssh-ed25519 AAAA test@host","notes":"lab node"}'
	)!
	assert res8.status_code == 200
	updated := json2.decode[MachineDto](res8.body)!
	assert updated.hostname == 'renamed'
	assert updated.username == 'timi'
	assert updated.ssh_keys == 'ssh-ed25519 AAAA test@host'
	assert updated.notes == 'lab node'
	assert updated.has_password
	assert updated.storage_layout == 'zfs'
	assert updated.boot_mode == 'nfs'

	// a machine without hostname cannot be approved
	res9 := http.fetch(
		method: .post
		url:    '${test_base}/api/machines'
		header: h_json_auth(token)
		data:   '{"mac":"bc:24:11:00:24:01"}'
	)!
	no_host := json2.decode[MachineDto](res9.body)!
	res10 := http.fetch(
		method: .post
		url:    '${test_base}/api/machines/${no_host.id}/approve'
		header: h_json_auth(token)
		data:   '{}'
	)!
	assert res10.status_code == 400

	// approve
	res11 := http.fetch(
		method: .post
		url:    '${test_base}/api/machines/${created.id}/approve'
		header: h_json_auth(token)
		data:   '{}'
	)!
	assert res11.status_code == 200
	approved := json2.decode[MachineDto](res11.body)!
	assert approved.status == 'approved'
	assert approved.approved_at > 0

	// reinstall bumps install_count and re-arms
	res12 := http.fetch(
		method: .post
		url:    '${test_base}/api/machines/${created.id}/reinstall'
		header: h_auth(token)
	)!
	assert res12.status_code == 200
	reinstalled := json2.decode[MachineDto](res12.body)!
	assert reinstalled.status == 'approved'
	assert reinstalled.install_count == 1

	// phone-home (no auth) flips to installed
	res13 := http.fetch(
		method: .post
		url:    '${test_base}/api/machines/installed'
		data:   'mac=bc:24:11:00:24:99&hostname=renamed'
	)!
	assert res13.status_code == 200
	res14 := http.fetch(url: '${test_base}/api/machines/${created.id}', header: h_auth(token))!
	home := json2.decode[MachineDto](res14.body)!
	assert home.status == 'installed'
	assert home.installed_at > 0

	// phone-home for unknown MAC -> 404
	res15 := http.fetch(
		method: .post
		url:    '${test_base}/api/machines/installed'
		data:   'mac=aa:bb:cc:dd:ee:ff'
	)!
	assert res15.status_code == 404

	// filter by status
	res16 := http.fetch(url: '${test_base}/api/machines?status=pending', header: h_auth(token))!
	assert json2.decode[[]MachineDto](res16.body)!.len == 1

	// delete
	res17 := http.fetch(
		method: .delete
		url:    '${test_base}/api/machines/${created.id}'
		header: h_auth(token)
	)!
	assert res17.status_code == 200
	res18 := http.fetch(url: '${test_base}/api/machines', header: h_auth(token))!
	assert json2.decode[[]MachineDto](res18.body)!.len == 1

	// logout invalidates the token
	res19 := http.fetch(method: .post, url: '${test_base}/api/auth/logout', header: h_auth(token))!
	assert res19.status_code == 200
	res20 := http.fetch(url: '${test_base}/api/auth/me', header: h_auth(token))!
	assert res20.status_code == 401
}

module server

import os
import veb
import internal.webdist

// spa serves the embedded Next.js static export from an in-memory cache built
// once at startup. veb orders variadic catch-all routes after every exact
// route, so /api, /os, /assets and /boot.ipxe match their own handlers first;
// the prefix guard below turns unknown paths under those prefixes into 404
// instead of serving the app shell.
@['/:path...'; get]
pub fn (mut app App) spa(mut ctx Context, path string) veb.Result {
	if is_reserved_path(path) {
		return seed_not_found(mut ctx)
	}
	if !app.spa_enabled {
		ctx.res.set_status(.not_found)
		return ctx.text('the web UI is not available: frontend files are missing from this build')
	}
	// React Server Component payload requests (client-side navigation/prefetch):
	// the App Router asks for "<route>?_rsc=..." or "<route>.txt?_rsc=..." and
	// expects the "<route>.txt" flight payload, never HTML.
	if ctx.query['_rsc'] != '' || (ctx.req.header.get_custom('RSC') or { '' }) != '' {
		mut target := path.trim_right('/')
		if target == '' {
			target = '/index'
		}
		if !target.ends_with('.txt') {
			target += '.txt'
		}
		if canonical := webdist.resolve(target) {
			if content := app.spa_files[canonical] {
				return serve_spa_file(mut ctx, canonical, content)
			}
		}
		return seed_not_found(mut ctx)
	}
	if canonical := webdist.resolve(path) {
		if content := app.spa_files[canonical] {
			return serve_spa_file(mut ctx, canonical, content)
		}
	}
	if content := app.spa_files['/404.html'] {
		ctx.res.set_status(.not_found)
		return serve_spa_file(mut ctx, '/404.html', content)
	}
	if content := app.spa_files['/index.html'] {
		return serve_spa_file(mut ctx, '/index.html', content)
	}
	ctx.res.set_status(.not_found)
	return ctx.text('the web UI is not available: frontend files are missing from this build')
}

fn is_reserved_path(path string) bool {
	return path.starts_with('/api') || path.starts_with('/os') || path.starts_with('/assets')
		|| path.starts_with('/boot.ipxe') || path.starts_with('/healthz')
}

// load_spa materializes the embedded UI into memory once at startup. In dev
// builds the embedded data would otherwise be read from web/out lazily (and
// panic when a file vanishes mid-run, killing the whole server); preloading
// turns that into a graceful "UI unavailable" state instead.
fn (mut app App) load_spa() {
	$if prod {
	} $else {
		if !webdist.sources_present() {
			eprintln('[spa] web/out is missing: serving API/iPXE only, UI disabled')
			app.spa_enabled = false
			return
		}
	}
	mut cache := map[string]string{}
	for p in webdist.paths() {
		f := webdist.get(p) or { continue }
		cache[p] = f.to_bytes().bytestr()
	}
	if cache.len == 0 {
		app.spa_enabled = false
		eprintln('[spa] no embedded frontend files: UI disabled')
		return
	}
	app.spa_files = cache
	app.spa_enabled = true
}

fn serve_spa_file(mut ctx Context, path string, content string) veb.Result {
	ext := os.file_ext(path)
	// every .txt file in the Next static export is an RSC flight payload
	mime := if ext == '.txt' {
		'text/x-component'
	} else if ext != '' {
		veb.mime_types[ext] or { 'application/octet-stream' }
	} else {
		'application/octet-stream'
	}
	if path.starts_with('/_next/static/') {
		ctx.res.header.set(.cache_control, 'public, max-age=31536000, immutable')
	} else {
		ctx.res.header.set(.cache_control, 'no-cache')
	}
	return ctx.send_response_to_client(mime, content)
}

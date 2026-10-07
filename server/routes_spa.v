module server

import os
import v.embed_file
import veb
import webdist

// spa serves the embedded single-page app. veb orders variadic catch-all
// routes after every exact route, so /api, /os, /assets and /boot.ipxe match
// their own handlers first; the prefix guard below turns unknown paths under
// those prefixes into 404 instead of serving index.html.
@['/:path...'; get]
pub fn (mut app App) spa(mut ctx Context, path string) veb.Result {
	if is_reserved_path(path) {
		return seed_not_found(mut ctx)
	}
	if f := webdist.get(path) {
		return serve_embedded_file(mut ctx, path, f)
	}
	if idx := webdist.index() {
		return serve_embedded_file(mut ctx, '/index.html', idx)
	}
	ctx.res.set_status(.not_found)
	return ctx.text('the web UI is not embedded in this build')
}

fn is_reserved_path(path string) bool {
	return path.starts_with('/api') || path.starts_with('/os') || path.starts_with('/assets')
		|| path.starts_with('/boot.ipxe') || path.starts_with('/healthz')
}

fn serve_embedded_file(mut ctx Context, path string, f embed_file.EmbedFileData) veb.Result {
	ext := os.file_ext(path)
	mime := if ext != '' {
		veb.mime_types[ext] or { 'application/octet-stream' }
	} else {
		'application/octet-stream'
	}
	if path.starts_with('/assets/') {
		ctx.res.header.set(.cache_control, 'public, max-age=31536000, immutable')
	} else {
		ctx.res.header.set(.cache_control, 'no-cache')
	}
	return ctx.send_response_to_client(mime, f.to_bytes().bytestr())
}

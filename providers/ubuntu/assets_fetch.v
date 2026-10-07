module ubuntu

import net.http
import os
import strconv

const iso_name_suffix = '-live-server-amd64.iso'

// refresh_status marks the manager ready when the files are already present
// (e.g. after a restart, when the in-memory status was reset). It never
// triggers a fetch.
pub fn (mut am AssetManager) refresh_status(version string) {
	if am.status_snapshot(version).phase == .idle && am.ready(version) {
		am.set_status(.ready, version, 'assets available')
	}
}

// ensure_assets starts a background fetch/extract when the kernel/initrd for
// `version` are not available yet. Safe to call on every boot request.
pub fn (mut am AssetManager) ensure_assets(version string) {
	if am.ready(version) {
		if am.status_snapshot(version).phase != .ready {
			am.set_status(.ready, version, 'assets available')
		}
		return
	}
	if am.status_snapshot(version).phase in [.downloading, .extracting] {
		return
	}
	spawn am.fetch_worker(version)
}

fn (mut am AssetManager) fetch_worker(version string) {
	dest := am.version_dir(version)
	os.mkdir_all(dest) or {
		am.fail(version, 'cannot create ${dest}: ${err.msg()}')
		return
	}
	// 1. local ISO (recommended when it is the same ISO the NFS rootfs mounts)
	if am.local_iso != '' {
		am.set_status(.extracting, version, 'extracting kernel/initrd from ${am.local_iso}')
		extract_from_iso(am.local_iso, dest) or {
			am.fail(version, err.msg())
			return
		}
		am.finish_ok(version, 'iso:${am.local_iso}')
		return
	}
	// 2. download the latest ${version}.x ISO from releases.ubuntu.com once
	url := discover_latest_iso_url(version) or {
		am.fail(version, 'cannot find an ISO to download: ${err.msg()}')
		return
	}
	iso_path := os.join_path(dest, 'ubuntu-${version}-download.iso')
	am.set_status(.downloading, version, 'downloading ${url}')
	http.download_file_with_progress(url, iso_path,
		downloader: &ProgressDownloader{
			am:      am
			version: version
		}
	) or {
		am.fail(version, 'download failed: ${err.msg()}')
		return
	}
	am.set_status(.extracting, version, 'extracting kernel/initrd from the downloaded ISO')
	extract_from_iso(iso_path, dest) or {
		am.fail(version, err.msg())
		return
	}
	if am.keep_iso {
		am.finish_ok(version, 'downloaded (ISO kept at ${iso_path})')
	} else {
		os.rm(iso_path) or {}
		am.finish_ok(version, 'downloaded')
	}
}

fn (mut am AssetManager) finish_ok(version string, source string) {
	am.mu.lock()
	mut st := am.statuses[version] or { AssetStatus{ version: version } }
	st.phase = .ready
	st.source = source
	st.message = 'assets ready (${source})'
	st.percent = 100
	am.statuses[version] = st
	am.mu.unlock()
	eprintln('[assets] ready: ubuntu ${version} (${source})')
}

// ProgressDownloader streams the download to disk and reports progress.
struct ProgressDownloader {
mut:
	am      &AssetManager = unsafe { nil }
	version string
	file    os.File
}

fn (mut d ProgressDownloader) on_start(mut _request http.Request, path string) ! {
	d.file = os.create(path)!
}

fn (mut d ProgressDownloader) on_chunk(_request &http.Request, chunk []u8, already_received u64, expected u64) ! {
	d.file.write(chunk)!
	if d.am != unsafe { nil } {
		d.am.set_progress(d.version, i64(already_received), i64(expected))
	}
}

fn (mut d ProgressDownloader) on_finish(_request &http.Request, _response &http.Response) ! {
	d.file.close()
}

// discover_latest_iso_url scrapes the releases directory for a version and
// returns the ISO to download: for a pinned point release (x.y.z) the exact
// ubuntu-<version>-live-server-amd64.iso in releases.ubuntu.com/<version>/,
// otherwise the newest .N of the series.
fn discover_latest_iso_url(version string) !string {
	base_url := 'https://releases.ubuntu.com/${version}/'
	resp := http.get(base_url)!
	if resp.status_code != 200 {
		return error('listing ${base_url} returned HTTP ${resp.status_code}')
	}
	name := pick_iso_filename(resp.body, version) or {
		return error('no ISO for "${version}" found on ${base_url}')
	}
	return base_url + name
}

// pick_iso_filename finds the ISO name for `version` in an HTML directory
// listing (hrefs are split on '"'). A pinned version (x.y.z) matches only the
// exact ubuntu-<version>-live-server-amd64.iso; a series (x.y) picks the
// highest ubuntu-<version>.N-live-server-amd64.iso.
pub fn pick_iso_filename(html string, version string) ?string {
	if version.split('.').len == 3 {
		exact := 'ubuntu-${version}${iso_name_suffix}'
		for seg in html.split('"') {
			if seg == exact {
				return exact
			}
		}
		return none
	}
	prefix := 'ubuntu-${version}.'
	mut best := ''
	mut best_n := 0
	for seg in html.split('"') {
		if seg.starts_with(prefix) && seg.ends_with(iso_name_suffix) {
			n_str := seg[prefix.len..seg.len - iso_name_suffix.len]
			n := strconv.atoi(n_str) or { -1 }
			if n > best_n {
				best_n = n
				best = seg
			}
		}
	}
	if best == '' {
		return none
	}
	return best
}

fn find_extractor() ?string {
	tools := available_extractors()
	if tools.len == 0 {
		return none
	}
	return tools[0]
}

// available_extractors lists the ISO extraction tools present on this host.
pub fn available_extractors() []string {
	mut out := []string{}
	for tool in ['xorriso', '7z', 'bsdtar'] {
		if _ := os.find_abs_path_of_executable(tool) {
			out << tool
		}
	}
	return out
}

fn extract_from_iso(iso_path string, dest_dir string) ! {
	tool := find_extractor() or {
		return error('no ISO extraction tool found: install xorriso, p7zip-full, or libarchive (bsdtar)')
	}
	os.mkdir_all(dest_dir)!
	match tool {
		'xorriso' {
			run_cmd(['xorriso', '-osirrox', 'on', '-indev', iso_path, '-extract', '/casper/vmlinuz',
				os.join_path(dest_dir, 'vmlinuz')])!
			run_cmd(['xorriso', '-osirrox', 'on', '-indev', iso_path, '-extract', '/casper/initrd',
				os.join_path(dest_dir, 'initrd')])!
		}
		'7z' {
			run_cmd(['7z', 'e', '-y', '-o${dest_dir}', iso_path, 'casper/vmlinuz', 'casper/initrd'])!
		}
		'bsdtar' {
			tmp := os.join_path(dest_dir, '.extract_tmp')
			os.mkdir_all(tmp)!
			run_cmd(['bsdtar', '-xf', iso_path, '-C', tmp, 'casper/vmlinuz', 'casper/initrd'])!
			os.mv(os.join_path(tmp, 'casper', 'vmlinuz'), os.join_path(dest_dir, 'vmlinuz'))!
			os.mv(os.join_path(tmp, 'casper', 'initrd'), os.join_path(dest_dir, 'initrd'))!
			os.rmdir_all(tmp) or {}
		}
		else {
			return error('unsupported extractor "${tool}"')
		}
	}
	kernel := os.join_path(dest_dir, 'vmlinuz')
	initrd := os.join_path(dest_dir, 'initrd')
	if !os.exists(kernel) || os.file_size(kernel) < 1024 {
		return error('extraction produced no usable vmlinuz (${tool})')
	}
	if !os.exists(initrd) || os.file_size(initrd) < 1024 {
		return error('extraction produced no usable initrd (${tool})')
	}
}

fn run_cmd(args []string) ! {
	res := os.exec(args)
	if res.exit_code != 0 {
		return error('command failed (${res.exit_code}): ${args.join(' ')}\n${res.output}')
	}
}

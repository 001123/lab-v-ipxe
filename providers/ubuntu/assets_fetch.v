module ubuntu

import crypto.sha256
import net.http
import os
import strconv
import time

const iso_name_suffix = '-live-server-amd64.iso'

// an automatically retried fetch gives up after this many consecutive failures
// and waits for a manual retry from the settings UI
const max_auto_attempts = 3

// refresh_status marks the manager ready when the files are already present
// (e.g. after a restart, when the in-memory status was reset). It never
// triggers a fetch.
pub fn (mut am AssetManager) refresh_status(version string) {
	if am.status_snapshot(version).phase == .idle && am.ready(version) {
		am.set_status(.ready, version, 'assets available')
	}
}

// ensure_assets starts a background fetch/extract when the kernel/initrd for
// `version` are not available yet. Safe to call on every boot request: the
// fetch is claimed before the worker starts, and a failed fetch is retried
// automatically only up to max_auto_attempts times with backoff, so a boot
// loop cannot hammer the release mirror.
pub fn (mut am AssetManager) ensure_assets(version string) {
	am.request_fetch(version, false)
}

// fetch_assets_now retries immediately, bypassing the automatic-retry backoff
// and attempt cap. Used for explicit operator actions.
pub fn (mut am AssetManager) fetch_assets_now(version string) {
	am.request_fetch(version, true)
}

fn (mut am AssetManager) request_fetch(version string, force bool) {
	if am.ready(version) {
		if am.status_snapshot(version).phase != .ready {
			am.set_status(.ready, version, 'assets available')
		}
		return
	}
	am.mu.lock()
	mut st := am.statuses[version] or { AssetStatus{ version: version } }
	if st.phase in [.downloading, .extracting] {
		am.mu.unlock()
		return
	}
	if st.phase == .failed && !force {
		backoff_active := time.now().unix() - st.last_fail_at < auto_retry_delay(st.attempts)
		if st.attempts >= max_auto_attempts || backoff_active {
			am.mu.unlock()
			return
		}
	}
	// claim the version before spawning: concurrent boot requests must see the
	// fetch as running instead of each spawning their own worker
	st.phase = .downloading
	st.message = 'fetching ubuntu ${version} assets'
	st.percent = 0
	st.bytes_done = 0
	st.bytes_total = 0
	am.statuses[version] = st
	am.mu.unlock()
	spawn am.fetch_worker(version)
}

// auto_retry_delay is the wait in seconds before the next automatic attempt
// after `attempts` consecutive failures.
fn auto_retry_delay(attempts int) i64 {
	return if attempts <= 1 { 30 } else { 120 }
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
	iso_name := url.all_after_last('/')
	iso_path := os.join_path(dest, 'ubuntu-${version}-download.iso')
	part_path := '${iso_path}.part'
	am.set_status(.downloading, version, 'downloading ${url}')
	http.download_file_with_progress(url, part_path,
		downloader: &ProgressDownloader{
			am:      am
			version: version
		}
	) or {
		os.rm(part_path) or {}
		am.fail(version, 'download failed: ${err.msg()}')
		return
	}
	am.set_status(.downloading, version, 'verifying ${iso_name} against SHA256SUMS')
	expected := fetch_expected_sha256(url, iso_name) or {
		os.rm(part_path) or {}
		am.fail(version, 'cannot verify the download: ${err.msg()}')
		return
	}
	actual := sha256_of_file(part_path) or {
		os.rm(part_path) or {}
		am.fail(version, 'cannot hash the downloaded ISO: ${err.msg()}')
		return
	}
	if actual.to_lower() != expected.to_lower() {
		os.rm(part_path) or {}
		am.fail(version, 'checksum mismatch for ${iso_name}: expected ${expected}, got ${actual}')
		return
	}
	os.mv(part_path, iso_path) or {
		os.rm(part_path) or {}
		am.fail(version, 'cannot move the verified ISO into place: ${err.msg()}')
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
	st.attempts = 0
	st.last_fail_at = 0
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

// fetch_expected_sha256 downloads SHA256SUMS from the ISO's release directory
// and returns the expected hash for `iso_name`.
fn fetch_expected_sha256(iso_url string, iso_name string) !string {
	sums_url := '${iso_url.all_before_last('/')}/SHA256SUMS'
	resp := http.get(sums_url)!
	if resp.status_code != 200 {
		return error('${sums_url} returned HTTP ${resp.status_code}')
	}
	expected := parse_sha256sums(resp.body, iso_name) or {
		return error('no SHA256SUMS entry for ${iso_name} in ${sums_url}')
	}
	return expected
}

// parse_sha256sums finds the digest for `name` in a SHA256SUMS file, whose
// lines look like "<64 hex chars> *<file name>".
pub fn parse_sha256sums(body string, name string) ?string {
	for line in body.split_into_lines() {
		fields := line.trim_space().fields()
		if fields.len == 2 && fields[0].len == 64 && fields[1].trim_left('*') == name {
			return fields[0]
		}
	}
	return none
}

// sha256_of_file hashes a file in 1 MiB chunks, so large ISOs never have to
// fit in memory.
fn sha256_of_file(path string) !string {
	mut f := os.open(path)!
	defer {
		f.close()
	}
	mut d := sha256.new()
	mut buf := []u8{len: 1024 * 1024}
	for {
		n := f.read(mut buf) or {
			if err is os.Eof {
				break
			}
			return error('read ${path}: ${err.msg()}')
		}
		if n > 0 {
			d.write(buf[..n])!
		}
	}
	mut hash := []u8{len: sha256.size}
	d.checksum_into(mut hash)
	return hash.hex()
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

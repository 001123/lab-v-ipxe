module server

import os
import time

pub struct ProcessMemInfo {
pub:
	name         string
	pid          int
	memory_bytes i64
	mode         string
	port         int
}

pub struct SystemInfo {
pub:
	backend         ProcessMemInfo
	frontend        ProcessMemInfo
	os_type         string
	uptime_sec      i64
	unified_process bool
	port            int
}

fn (app &App) get_system_info() SystemInfo {
	be_port := if app.cfg.port > 0 { app.cfg.port } else { 4793 }
	fe_port_str := os.getenv_opt('LAB_V_IPXE_WEB_PORT') or { '4794' }
	fe_port := fe_port_str.int()

	mut fe_pid := 0
	mut fe_mem := i64(0)
	$if !prod {
		res := os.exec(['lsof', '-i', ':${fe_port}', '-sTCP:LISTEN', '-t'])
		if res.exit_code == 0 && res.output.trim_space() != '' {
			lines := res.output.trim_space().split_into_lines()
			if lines.len > 0 {
				pid := lines[0].trim_space().int()
				if pid > 0 {
					fe_pid = pid
					ps_res := os.exec(['ps', '-o', 'rss=', '-p', pid.str()])
					if ps_res.exit_code == 0 {
						kb := ps_res.output.trim_space().i64()
						fe_mem = kb * 1024
					}
				}
			}
		}
	}

	is_unified := $if prod {
		true
	} $else {
		fe_pid == 0
	}

	be_mem := get_rss_bytes(os.getpid())
	be_info := ProcessMemInfo{
		name:         if is_unified { 'Backend & App Server' } else { 'Backend (V / veb)' }
		pid:          os.getpid()
		memory_bytes: be_mem
		mode:         if is_unified { 'Single binary (port :${be_port})' } else { 'Dev server (port :${be_port})' }
		port:         be_port
	}

	fe_info := if is_unified {
		ProcessMemInfo{
			name:         'Frontend (Embedded UI)'
			pid:          os.getpid()
			memory_bytes: 0
			mode:         'Embedded in binary (served on :${be_port})'
			port:         be_port
		}
	} else {
		ProcessMemInfo{
			name:         'Frontend (Next.js)'
			pid:          fe_pid
			memory_bytes: fe_mem
			mode:         'Node.js dev server (port :${fe_port})'
			port:         fe_port
		}
	}

	return SystemInfo{
		backend:         be_info
		frontend:        fe_info
		os_type:         os.user_os()
		uptime_sec:      if app.start_time > 0 { time.now().unix() - app.start_time } else { 0 }
		unified_process: is_unified
		port:            be_port
	}
}

fn get_rss_bytes(pid int) i64 {
	mut mem := i64(0)
	$if linux {
		if content := os.read_file('/proc/${pid}/status') {
			for line in content.split_into_lines() {
				if line.starts_with('VmRSS:') {
					parts := line.all_after('VmRSS:').trim_space().split(' ')
					if parts.len > 0 {
						kb := parts[0].trim_space().i64()
						if kb > 0 {
							mem = kb * 1024
						}
					}
					break
				}
			}
		}
	}
	if mem == 0 {
		res := os.exec(['ps', '-o', 'rss=', '-p', pid.str()])
		if res.exit_code == 0 {
			kb := res.output.trim_space().i64()
			mem = kb * 1024
		}
	}
	return mem
}

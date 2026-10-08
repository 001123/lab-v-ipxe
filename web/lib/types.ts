export type MachineStatus = 'pending' | 'approved' | 'installing' | 'installed'
export type BootMode = 'nfs' | 'http'
export type StorageLayout = 'zfs' | 'direct' | 'lvm'

export interface Machine {
  id: number
  mac: string
  hostname: string
  status: MachineStatus
  boot_mode: BootMode
  storage_layout: StorageLayout
  storage_disk: string
  keep_ipxe_first: boolean
  os_name: string
  os_version: string
  username: string
  ssh_keys: string
  nfs_root: string
  notes: string
  install_count: number
  has_password: boolean
  auto_created: boolean
  approved_at: number
  installed_at: number
  last_seen_at: number
  created_at: number
  updated_at: number
}

export interface MachinePayload {
  mac?: string
  hostname?: string
  username?: string
  password?: string
  ssh_keys?: string
  nfs_root?: string
  notes?: string
  os_name?: string
  os_version?: string
  boot_mode?: BootMode
  storage_layout?: StorageLayout
  storage_disk?: string
  keep_ipxe_first?: boolean
}

export interface LoginRes {
  token: string
  user: { email: string }
}

export type AssetPhase = 'idle' | 'downloading' | 'extracting' | 'ready' | 'failed'

export interface AssetStatus {
  os_name: string
  phase: AssetPhase
  version: string
  message: string
  percent: number
  bytes_done: number
  bytes_total: number
  source: string
}

export interface OsImage {
  os_name: string
  version: string
  nfs_root: string
  is_default: boolean
}

export interface ProviderInfo {
  name: string
  display_name: string
  versions: string[]
}

export interface ProcessMemInfo {
  name: string
  pid: number
  memory_bytes: number
  mode: string
  port?: number
}

export interface SystemInfo {
  backend: ProcessMemInfo
  frontend: ProcessMemInfo
  os_type: string
  uptime_sec: number
  unified_process?: boolean
  port?: number
}

export interface SettingsRes {
  data_dir: string
  db_path: string
  base_url_override: string
  ssh_keys_default: string
  os_images: OsImage[]
  providers: ProviderInfo[]
  extractors: string[]
  assets: AssetStatus[]
  system?: SystemInfo
}

export interface SettingsPayload {
  ssh_keys_default?: string
  base_url_override?: string
  os_images?: OsImage[]
}

export interface AssetFetchPayload {
  os_name?: string
  version?: string
}

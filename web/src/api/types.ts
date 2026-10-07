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
}

export interface LoginRes {
  token: string
  user: { email: string }
}

export interface AssetStatus {
  phase: 'idle' | 'downloading' | 'extracting' | 'ready' | 'failed'
  version: string
  message: string
  percent: number
  bytes_done: number
  bytes_total: number
  source: string
}

export interface SettingsRes {
  data_dir: string
  db_path: string
  base_url_override: string
  nfs_root_default: string
  ubuntu_version: string
  extractors: string[]
  assets: AssetStatus
}

export interface SettingsPayload {
  nfs_root_default?: string
  ubuntu_version?: string
  base_url_override?: string
}

'use client'

import { useState } from 'react'
import {
  CheckIcon,
  CpuIcon,
  EyeIcon,
  EyeOffIcon,
  FileTextIcon,
  HardDriveIcon,
  Loader2Icon,
  SaveIcon,
  ServerIcon,
  XIcon,
} from 'lucide-react'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { cn } from '@/lib/utils'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@/components/ui/sheet'
import { Textarea } from '@/components/ui/textarea'
import { useMachines } from '@/hooks/use-machines'
import { useSettings } from '@/hooks/use-settings'
import { apiErrorMessage } from '@/lib/api'
import { defaultImage, imageLabel } from '@/lib/os-images'
import type { BootMode, Machine, MachinePayload, OsImage, StorageLayout } from '@/lib/types'

export type MachineSheetMode = 'create' | 'approve' | 'edit'

const BOOT_MODE_OPTIONS = [
  { label: 'NFS (via Proxmox NFS export)', value: 'nfs' },
  { label: 'Public HTTP (not implemented yet)', value: 'http', disabled: true },
]

const STORAGE_OPTIONS = [
  { label: 'Direct (ext4)', value: 'direct' },
  { label: 'ZFS root', value: 'zfs' },
  { label: 'LVM', value: 'lvm' },
]

function normalizeMacInput(v: string): string {
  return v.toUpperCase().replace(/[^0-9A-F:.-]/g, '')
}

function isValidMac(v: string): boolean {
  const hex = v.replace(/[:.-]/g, '')
  return /^[0-9A-F]{12}$/.test(hex)
}

function initForm(machine: Machine | null, images: OsImage[]): MachinePayload {
  if (machine) {
    return {
      mac: machine.mac,
      hostname: machine.hostname,
      username: machine.username,
      password: '',
      ssh_keys: machine.ssh_keys,
      nfs_root: machine.nfs_root,
      notes: machine.notes,
      os_name: machine.os_name,
      os_version: machine.os_version,
      boot_mode: machine.boot_mode,
      storage_layout: machine.storage_layout,
      storage_disk: machine.storage_disk,
    }
  }
  const fallback = defaultImage(images)
  return {
    mac: '',
    hostname: '',
    username: '',
    password: '',
    ssh_keys: '',
    nfs_root: '',
    notes: '',
    os_name: fallback?.os_name ?? 'ubuntu',
    os_version: fallback?.version ?? '26.04.1',
    boot_mode: 'nfs',
    storage_layout: 'direct',
    storage_disk: '',
  }
}

interface MachineSheetProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  machine: Machine | null
  mode: MachineSheetMode
}

export function MachineSheet({ open, onOpenChange, machine, mode }: MachineSheetProps) {
  const { create, approve, update } = useMachines(0)
  const { settings } = useSettings()
  const images = settings?.os_images ?? []
  const providers = settings?.providers ?? []
  const [form, setForm] = useState<MachinePayload>({})
  const [showPassword, setShowPassword] = useState(false)
  const [overrideSshKeys, setOverrideSshKeys] = useState(false)
  const [overrideNfsRoot, setOverrideNfsRoot] = useState(false)
  const [saving, setSaving] = useState(false)
  const [wasOpen, setWasOpen] = useState(false)

  // reset the form on each open (adjusting state during render, no effect needed)
  if (open !== wasOpen) {
    setWasOpen(open)
    if (open) {
      setForm(initForm(machine, images))
      setShowPassword(false)
      setOverrideSshKeys(Boolean(machine?.ssh_keys && machine.ssh_keys.trim() !== ''))
      setOverrideNfsRoot(Boolean(machine?.nfs_root && machine.nfs_root.trim() !== ''))
    }
  }

  function set<K extends keyof MachinePayload>(key: K, value: MachinePayload[K]) {
    setForm((f) => ({ ...f, [key]: value }))
  }

  async function onSave() {
    if (mode !== 'edit' && !form.mac) {
      toast.warning('MAC address is required')
      return
    }
    if (form.mac && !isValidMac(form.mac)) {
      toast.warning('Invalid MAC address')
      return
    }
    if (mode === 'approve' && !form.hostname) {
      toast.warning('Hostname is required to approve')
      return
    }
    if (mode === 'create' && !form.hostname) {
      toast.warning('Hostname is required')
      return
    }
    const disk = form.storage_disk?.trim() ?? ''
    if (disk && disk !== 'auto' && !disk.startsWith('/dev/')) {
      toast.warning('Install disk must be a /dev/... path (or "auto" to reset)')
      return
    }
    if (overrideSshKeys && !form.ssh_keys?.trim()) {
      toast.warning('Please enter SSH keys or uncheck the override box')
      return
    }
    if (overrideNfsRoot && !form.nfs_root?.trim()) {
      toast.warning('Please enter an NFS export override or uncheck the box')
      return
    }
    const payload: MachinePayload = {
      ...form,
      ssh_keys: overrideSshKeys ? (form.ssh_keys?.trim() ?? '') : 'auto',
      nfs_root: overrideNfsRoot ? (form.nfs_root?.trim() ?? '') : 'auto',
    }
    setSaving(true)
    try {
      if (mode === 'create') {
        await create(payload)
        toast.success('Machine created')
      } else if (mode === 'approve' && machine) {
        await approve(machine.id, payload)
        toast.success(`Approved ${machine.hostname || 'machine'}`)
      } else if (machine) {
        await update(machine.id, payload)
        toast.success('Saved')
      }
      onOpenChange(false)
    } catch (err) {
      toast.error(apiErrorMessage(err))
    } finally {
      setSaving(false)
    }
  }

  const title = mode === 'create' ? 'Add machine' : mode === 'approve' ? 'Approve machine' : 'Edit machine'

  const currentImageKey = `${form.os_name ?? ''}/${form.os_version ?? ''}`
  const selectedImage = images.find(
    (img) => img.os_name === form.os_name && img.version === form.os_version
  )
  const osImageItems: { value: string; label: string; disabled?: boolean }[] = images.map((img) => ({
    value: `${img.os_name}/${img.version}`,
    label: imageLabel(img, providers),
  }))
  if (form.os_name && !images.some((img) => `${img.os_name}/${img.version}` === currentImageKey)) {
    osImageItems.push({
      value: currentImageKey,
      label: `${form.os_name} ${form.os_version} (not configured)`,
      disabled: true,
    })
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent
        side="right"
        className="w-full max-w-full sm:max-w-[520px] data-[side=right]:w-full data-[side=right]:max-w-full sm:data-[side=right]:max-w-[520px] p-0 gap-0 flex flex-col h-full"
      >
        <SheetHeader className="p-4 sm:px-6 sm:py-5 border-b bg-background/95 backdrop-blur-sm shrink-0 pr-12">
          <div className="flex items-center gap-2 flex-wrap">
            <SheetTitle className="text-base sm:text-lg font-semibold tracking-tight">{title}</SheetTitle>
            {mode === 'approve' && (
              <span className="rounded-full bg-amber-500/10 text-amber-600 dark:text-amber-400 border border-amber-500/20 px-2 py-0.5 text-[11px] font-medium">
                Pending approval
              </span>
            )}
            {mode === 'create' && (
              <span className="rounded-full bg-primary/10 text-primary border border-primary/20 px-2 py-0.5 text-[11px] font-medium">
                New
              </span>
            )}
          </div>
          <SheetDescription className="text-xs text-muted-foreground mt-0.5">
            {mode === 'approve'
              ? 'Verify host settings and boot configuration before activating this machine.'
              : mode === 'create'
              ? 'Register a new machine into the provisioning inventory.'
              : 'Modify system parameters, boot mode, and storage layout.'}
          </SheetDescription>
        </SheetHeader>

        <div className="flex-1 space-y-5 overflow-y-auto p-4 sm:p-6">
          {/* Section 1: Host & Credentials */}
          <div className="rounded-xl border bg-card/40 p-4 space-y-3.5 shadow-2xs">
            <div className="flex items-center gap-1.5 pb-1 border-b border-border/40 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
              <ServerIcon className="size-3.5 text-primary" />
              <span>Machine Identity</span>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
              <div className="grid gap-1.5 min-w-0">
                <Label htmlFor="machine-mac">
                  MAC address <span className="text-destructive">*</span>
                </Label>
                <Input
                  id="machine-mac"
                  value={form.mac ?? ''}
                  onChange={(e) => set('mac', normalizeMacInput(e.target.value))}
                  placeholder="BC:24:11:00:24:99"
                  className="font-mono text-xs sm:text-sm"
                  disabled={mode === 'edit' && !!machine}
                />
              </div>
              <div className="grid gap-1.5 min-w-0">
                <Label htmlFor="machine-hostname">
                  Hostname <span className="text-destructive">*</span>
                </Label>
                <Input
                  id="machine-hostname"
                  value={form.hostname ?? ''}
                  onChange={(e) => set('hostname', e.target.value)}
                  placeholder="vm-ztp-test"
                  className="text-xs sm:text-sm"
                />
              </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
              <div className="grid gap-1.5 min-w-0">
                <Label htmlFor="machine-username">Username</Label>
                <Input
                  id="machine-username"
                  value={form.username ?? ''}
                  onChange={(e) => set('username', e.target.value)}
                  placeholder="ubuntu"
                  className="text-xs sm:text-sm"
                />
              </div>
              <div className="grid gap-1.5 min-w-0">
                <Label htmlFor="machine-password">
                  {machine?.has_password
                    ? 'Password (keep current)'
                    : 'Password (default: ubuntu)'}
                </Label>
                <div className="relative">
                  <Input
                    id="machine-password"
                    type={showPassword ? 'text' : 'password'}
                    value={form.password ?? ''}
                    onChange={(e) => set('password', e.target.value)}
                    className="pr-9 text-xs sm:text-sm"
                  />
                  <Button
                    type="button"
                    variant="ghost"
                    size="icon-sm"
                    className="absolute top-0.5 right-0.5"
                    onClick={() => setShowPassword((v) => !v)}
                    aria-label={showPassword ? 'Hide password' : 'Show password'}
                  >
                    {showPassword ? <EyeOffIcon className="size-3.5" /> : <EyeIcon className="size-3.5" />}
                  </Button>
                </div>
              </div>
            </div>

            <div className="space-y-2.5 pt-1 border-t border-border/40">
              <div className="flex items-center gap-2">
                <Checkbox
                  id="machine-override-ssh"
                  checked={overrideSshKeys}
                  onCheckedChange={(checked) => {
                    const next = checked === true
                    setOverrideSshKeys(next)
                    if (!next) {
                      set('ssh_keys', '')
                    }
                  }}
                />
                <Label
                  htmlFor="machine-override-ssh"
                  className="text-xs sm:text-sm font-medium cursor-pointer select-none"
                >
                  Override global SSH authorized keys
                </Label>
              </div>

              {overrideSshKeys ? (
                <div className="grid gap-1.5 pl-6 pt-1">
                  <Textarea
                    id="machine-ssh-keys"
                    value={form.ssh_keys ?? ''}
                    onChange={(e) => set('ssh_keys', e.target.value)}
                    rows={3}
                    placeholder="ssh-ed25519 AAAA... user@host"
                    className="font-mono text-xs"
                    autoFocus
                  />
                  <p className="text-[11px] text-muted-foreground leading-normal">
                    One public key per line. These keys will replace the global keys from Settings for this machine.
                  </p>
                </div>
              ) : (
                <p className="text-[11px] text-muted-foreground pl-6 leading-normal">
                  Inheriting default SSH keys from <span className="font-medium text-foreground/80">Settings</span>.
                </p>
              )}
            </div>
          </div>

          {/* Section 2: OS & Boot Configuration */}
          <div className="rounded-xl border bg-card/40 p-4 space-y-3.5 shadow-2xs">
            <div className="flex items-center gap-1.5 pb-1 border-b border-border/40 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
              <CpuIcon className="size-3.5 text-primary" />
              <span>OS & Boot Configuration</span>
            </div>

            <div className="grid gap-1.5">
              <Label htmlFor="machine-os-image">OS image</Label>
              <Select
                items={osImageItems}
                value={currentImageKey}
                onValueChange={(value) => {
                  if (typeof value !== 'string') return
                  const slash = value.indexOf('/')
                  set('os_name', value.slice(0, slash))
                  set('os_version', value.slice(slash + 1))
                }}
              >
                <SelectTrigger id="machine-os-image" className="w-full">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {osImageItems.map((option) => (
                    <SelectItem key={option.value} value={option.value} disabled={option.disabled}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              {images.length === 0 && (
                <p className="text-[11px] text-muted-foreground">
                  No OS images configured yet — add one under Settings.
                </p>
              )}
            </div>

            <div className="grid gap-1.5">
              <Label htmlFor="machine-boot-mode">Boot mode</Label>
              <Select
                items={BOOT_MODE_OPTIONS}
                value={form.boot_mode ?? 'nfs'}
                onValueChange={(value) => {
                  if (typeof value === 'string') set('boot_mode', value as BootMode)
                }}
              >
                <SelectTrigger id="machine-boot-mode" className="w-full">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {BOOT_MODE_OPTIONS.map((option) => (
                    <SelectItem key={option.value} value={option.value} disabled={option.disabled}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2.5 pt-1 border-t border-border/40">
              <div className="flex items-center gap-2">
                <Checkbox
                  id="machine-override-nfs"
                  checked={overrideNfsRoot}
                  onCheckedChange={(checked) => {
                    const next = checked === true
                    setOverrideNfsRoot(next)
                    if (!next) {
                      set('nfs_root', '')
                    }
                  }}
                />
                <Label
                  htmlFor="machine-override-nfs"
                  className="text-xs sm:text-sm font-medium cursor-pointer select-none"
                >
                  Override NFS export path
                </Label>
              </div>

              {overrideNfsRoot ? (
                <div className="grid gap-1.5 pl-6 pt-1">
                  <Input
                    id="machine-nfs-root"
                    value={form.nfs_root ?? ''}
                    onChange={(e) => set('nfs_root', e.target.value)}
                    placeholder={selectedImage?.nfs_root ?? '192.168.250.4:/srv/nfs/ubuntu-26.04.1'}
                    className="font-mono text-xs sm:text-sm"
                    autoFocus
                  />
                  <p className="text-[11px] text-muted-foreground leading-normal">
                    Custom NFS export path for this machine (format: <code className="font-mono text-xs">host:/path</code>).
                  </p>
                </div>
              ) : (
                <p className="text-[11px] text-muted-foreground pl-6 leading-normal">
                  {selectedImage ? (
                    <>
                      Inheriting from selected OS image (
                      <code className="font-mono text-foreground/80">{selectedImage.nfs_root}</code>
                      ).
                    </>
                  ) : (
                    'Inheriting the default NFS export from the selected OS image.'
                  )}
                </p>
              )}
            </div>
          </div>

          {/* Section 3: Storage */}
          <div className="rounded-xl border bg-card/40 p-4 space-y-3.5 shadow-2xs">
            <div className="flex items-center gap-1.5 pb-1 border-b border-border/40 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
              <HardDriveIcon className="size-3.5 text-primary" />
              <span>Storage</span>
            </div>

            <div className="grid gap-1.5">
              <Label htmlFor="machine-storage">Storage layout</Label>
              <Select
                items={STORAGE_OPTIONS}
                value={form.storage_layout ?? 'direct'}
                onValueChange={(value) => {
                  if (typeof value === 'string') set('storage_layout', value as StorageLayout)
                }}
              >
                <SelectTrigger id="machine-storage" className="w-full">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {STORAGE_OPTIONS.map((option) => (
                    <SelectItem key={option.value} value={option.value}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="grid gap-1.5">
              <div className="flex items-center justify-between">
                <Label htmlFor="machine-storage-disk">Install disk</Label>
                <span className="text-[11px] text-muted-foreground">Empty = largest disk</span>
              </div>
              <Input
                id="machine-storage-disk"
                value={form.storage_disk ?? ''}
                onChange={(e) => set('storage_disk', e.target.value)}
                placeholder="/dev/nvme0n1 or /dev/disk/by-id/..."
                className="font-mono text-xs sm:text-sm"
              />
              <div className="flex flex-wrap items-center gap-1.5 pt-0.5">
                <span className="text-[11px] text-muted-foreground">Quick fill:</span>
                <button
                  type="button"
                  onClick={() =>
                    set('storage_disk', form.storage_disk === '/dev/nvme0n1' ? '' : '/dev/nvme0n1')
                  }
                  className={cn(
                    'font-mono text-[11px] px-2 py-0.5 rounded border transition-colors cursor-pointer',
                    form.storage_disk === '/dev/nvme0n1'
                      ? 'border-primary/50 bg-primary/10 text-primary font-medium'
                      : 'bg-muted/40 hover:bg-muted text-muted-foreground hover:text-foreground'
                  )}
                >
                  /dev/nvme0n1
                </button>
                <button
                  type="button"
                  onClick={() =>
                    set('storage_disk', form.storage_disk === '/dev/sda' ? '' : '/dev/sda')
                  }
                  className={cn(
                    'font-mono text-[11px] px-2 py-0.5 rounded border transition-colors cursor-pointer',
                    form.storage_disk === '/dev/sda'
                      ? 'border-primary/50 bg-primary/10 text-primary font-medium'
                      : 'bg-muted/40 hover:bg-muted text-muted-foreground hover:text-foreground'
                  )}
                >
                  /dev/sda
                </button>
              </div>
              <p className="text-[11px] text-muted-foreground leading-normal">
                Passed to the installer as the disk match path. Leave empty to pick the largest disk automatically; type &quot;auto&quot; to reset.
              </p>
            </div>
          </div>

          {/* Section 4: Notes */}
          <div className="rounded-xl border bg-card/40 p-4 space-y-3.5 shadow-2xs">
            <div className="flex items-center gap-1.5 pb-1 border-b border-border/40 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
              <FileTextIcon className="size-3.5 text-primary" />
              <span>Notes</span>
            </div>

            <div className="grid gap-1.5">
              <Label htmlFor="machine-notes">Machine notes</Label>
              <Textarea
                id="machine-notes"
                value={form.notes ?? ''}
                onChange={(e) => set('notes', e.target.value)}
                rows={3}
                placeholder="Optional machine notes, rack location, deployment tags, or remarks..."
                className="text-xs sm:text-sm resize-y"
              />
              <p className="text-[11px] text-muted-foreground leading-normal">
                Internal administrator notes; not sent to the machine during installation.
              </p>
            </div>
          </div>
        </div>

        <SheetFooter className="border-t bg-background/95 backdrop-blur-sm p-4 pb-8 sm:pb-4 flex flex-row items-center justify-end gap-2.5 shrink-0">
          <Button
            type="button"
            variant="outline"
            className="flex-1 sm:flex-initial"
            onClick={() => onOpenChange(false)}
          >
            <XIcon data-icon="inline-start" />
            Cancel
          </Button>
          <Button
            type="button"
            className="flex-1 sm:flex-initial min-w-[120px]"
            onClick={onSave}
            disabled={saving}
          >
            {saving ? (
              <Loader2Icon data-icon="inline-start" className="animate-spin" />
            ) : mode === 'approve' ? (
              <CheckIcon data-icon="inline-start" />
            ) : (
              <SaveIcon data-icon="inline-start" />
            )}
            {mode === 'approve' ? 'Approve' : 'Save'}
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}

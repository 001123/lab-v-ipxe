'use client'

import { useState } from 'react'
import { CheckIcon, EyeIcon, EyeOffIcon, Loader2Icon, SaveIcon, XIcon } from 'lucide-react'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Sheet, SheetContent, SheetFooter, SheetHeader, SheetTitle } from '@/components/ui/sheet'
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
    os_version: fallback?.version ?? '24.04',
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
  const [saving, setSaving] = useState(false)
  const [wasOpen, setWasOpen] = useState(false)

  // reset the form on each open (adjusting state during render, no effect needed)
  if (open !== wasOpen) {
    setWasOpen(open)
    if (open) {
      setForm(initForm(machine, images))
      setShowPassword(false)
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
    setSaving(true)
    try {
      if (mode === 'create') {
        await create(form)
        toast.success('Machine created')
      } else if (mode === 'approve' && machine) {
        await approve(machine.id, form)
        toast.success(`Approved ${machine.hostname || 'machine'}`)
      } else if (machine) {
        await update(machine.id, form)
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
        className="data-[side=right]:w-[480px] data-[side=right]:max-w-full data-[side=right]:sm:max-w-[480px]"
      >
        <SheetHeader>
          <SheetTitle>{title}</SheetTitle>
        </SheetHeader>
        <div className="flex-1 space-y-4 overflow-y-auto px-4">
          <div className="grid gap-1.5">
            <Label htmlFor="machine-mac">MAC address</Label>
            <Input
              id="machine-mac"
              value={form.mac ?? ''}
              onChange={(e) => set('mac', normalizeMacInput(e.target.value))}
              placeholder="BC:24:11:00:24:99"
              className="font-mono"
              disabled={mode === 'edit' && !!machine}
            />
          </div>
          <div className="grid gap-1.5">
            <Label htmlFor="machine-hostname">Hostname</Label>
            <Input
              id="machine-hostname"
              value={form.hostname ?? ''}
              onChange={(e) => set('hostname', e.target.value)}
              placeholder="vm-ztp-test"
            />
          </div>
          <div className="grid gap-1.5">
            <Label htmlFor="machine-username">Username</Label>
            <Input
              id="machine-username"
              value={form.username ?? ''}
              onChange={(e) => set('username', e.target.value)}
              placeholder="ubuntu"
            />
          </div>
          <div className="grid gap-1.5">
            <Label htmlFor="machine-password">
              {machine?.has_password
                ? 'Password (leave empty to keep current)'
                : 'Password (default: ubuntu)'}
            </Label>
            <div className="relative">
              <Input
                id="machine-password"
                type={showPassword ? 'text' : 'password'}
                value={form.password ?? ''}
                onChange={(e) => set('password', e.target.value)}
                className="pr-9"
              />
              <Button
                type="button"
                variant="ghost"
                size="icon-sm"
                className="absolute top-0.5 right-0.5"
                onClick={() => setShowPassword((v) => !v)}
                aria-label={showPassword ? 'Hide password' : 'Show password'}
              >
                {showPassword ? <EyeOffIcon /> : <EyeIcon />}
              </Button>
            </div>
          </div>
          <div className="grid gap-1.5">
            <Label htmlFor="machine-ssh-keys">SSH authorized keys (one per line)</Label>
            <Textarea
              id="machine-ssh-keys"
              value={form.ssh_keys ?? ''}
              onChange={(e) => set('ssh_keys', e.target.value)}
              rows={3}
              placeholder="ssh-ed25519 AAAA... user@host"
            />
            <p className="text-xs text-muted-foreground">
              Replaces the global keys from Settings. Leave empty to keep the current keys; type
              &quot;auto&quot; to clear them and inherit the global keys.
            </p>
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
              <p className="text-xs text-muted-foreground">
                No OS images configured yet — add one under Settings.
              </p>
            )}
          </div>
          <div className="grid gap-1.5">
            <Label htmlFor="machine-nfs-root">NFS export override</Label>
            <Input
              id="machine-nfs-root"
              value={form.nfs_root ?? ''}
              onChange={(e) => set('nfs_root', e.target.value)}
              placeholder={selectedImage?.nfs_root ?? '192.168.250.4:/srv/nfs/ubuntu-24.04'}
              className="font-mono"
            />
            <p className="text-xs text-muted-foreground">
              {selectedImage
                ? `Empty = inherit from the OS image (${selectedImage.nfs_root}).`
                : 'Empty = inherit the NFS export from the selected OS image.'}
            </p>
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
            <Label htmlFor="machine-storage-disk">Install disk (empty = largest disk)</Label>
            <Input
              id="machine-storage-disk"
              value={form.storage_disk ?? ''}
              onChange={(e) => set('storage_disk', e.target.value)}
              placeholder="/dev/nvme0n1 or /dev/disk/by-id/..."
              className="font-mono"
            />
            <p className="text-xs text-muted-foreground">
              Passed to the installer as the disk match path. Leave empty to pick the largest disk;
              type &quot;auto&quot; to reset.
            </p>
          </div>
          <div className="grid gap-1.5">
            <Label htmlFor="machine-notes">Notes</Label>
            <Textarea
              id="machine-notes"
              value={form.notes ?? ''}
              onChange={(e) => set('notes', e.target.value)}
              rows={2}
            />
          </div>
        </div>
        <SheetFooter className="flex-row justify-end">
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            <XIcon data-icon="inline-start" />
            Cancel
          </Button>
          <Button onClick={onSave} disabled={saving}>
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

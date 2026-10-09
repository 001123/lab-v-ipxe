'use client'

import { useEffect, useState } from 'react'
import {
  ActivityIcon,
  CircleCheckIcon,
  CircleXIcon,
  ClockIcon,
  CloudDownloadIcon,
  DownloadIcon,
  KeyRoundIcon,
  LaptopIcon,
  Loader2Icon,
  PackageOpenIcon,
  PlusIcon,
  RotateCcwIcon,
  SaveIcon,
  StarIcon,
  Trash2Icon,
  type LucideIcon,
} from 'lucide-react'
import { toast } from 'sonner'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Progress } from '@/components/ui/progress'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { Textarea } from '@/components/ui/textarea'
import { useSettings } from '@/hooks/use-settings'
import { api, apiErrorMessage } from '@/lib/api'
import { imageLabel } from '@/lib/os-images'
import type { AssetPhase, OsImage, ProviderInfo, SettingsRes, TestAptMirrorRes } from '@/lib/types'

interface Form {
  images: OsImage[]
  ssh_keys_default: string
  base_url_override: string
  apt_mirror_default: string
}

function areImagesEqual(a: OsImage[], b: OsImage[]): boolean {
  if (a.length !== b.length) return false
  for (let i = 0; i < a.length; i++) {
    if (
      a[i].os_name !== b[i].os_name ||
      a[i].version !== b[i].version ||
      a[i].nfs_root.trim() !== b[i].nfs_root.trim() ||
      Boolean(a[i].is_default) !== Boolean(b[i].is_default)
    ) {
      return false
    }
  }
  return true
}

function computeIsDirty(form: Form | null, settings: SettingsRes | undefined): boolean {
  if (!form || !settings) return false
  if (form.ssh_keys_default.trim() !== (settings.ssh_keys_default ?? '').trim()) return true
  if (form.base_url_override.trim() !== (settings.base_url_override ?? '').trim()) return true
  if (form.apt_mirror_default.trim() !== (settings.apt_mirror_default ?? '').trim()) return true
  if (!areImagesEqual(form.images, settings.os_images ?? [])) return true
  return false
}

interface SelectOption {
  value: string
  label: string
  disabled?: boolean
}

const NFS_ROOT_RE = /^[^\s:]+:\/.+$/

const PHASE_BADGES: Record<
  AssetPhase,
  { variant?: 'secondary' | 'destructive'; className?: string }
> = {
  idle: { variant: 'secondary' },
  downloading: { className: 'bg-blue-100 text-blue-900 dark:bg-blue-950 dark:text-blue-200' },
  extracting: { className: 'bg-amber-100 text-amber-900 dark:bg-amber-950 dark:text-amber-200' },
  ready: { className: 'bg-green-100 text-green-900 dark:bg-green-950 dark:text-green-200' },
  failed: { variant: 'destructive' },
}

const PHASE_ICONS: Record<AssetPhase, LucideIcon> = {
  idle: ClockIcon,
  downloading: DownloadIcon,
  extracting: PackageOpenIcon,
  ready: CircleCheckIcon,
  failed: CircleXIcon,
}

function osOptionsFor(providers: ProviderInfo[], img: OsImage): SelectOption[] {
  const options: SelectOption[] = providers.map((p) => ({ value: p.name, label: p.display_name }))
  if (!providers.some((p) => p.name === img.os_name)) {
    options.push({ value: img.os_name, label: `${img.os_name} (unknown)`, disabled: true })
  }
  return options
}

function versionOptionsFor(provider: ProviderInfo | undefined, img: OsImage): SelectOption[] {
  const options: SelectOption[] = (provider?.versions ?? []).map((v) => ({ value: v, label: v }))
  if (provider && !provider.versions.includes(img.version)) {
    options.push({ value: img.version, label: `${img.version} (not supported)`, disabled: true })
  }
  return options
}

function parseSshKeys(raw: string): {
  keys: { type: string; comment: string; full: string }[]
  error: string | null
} {
  const trimmed = raw.trim()
  if (!trimmed || trimmed === 'auto') return { keys: [], error: null }

  if (trimmed.includes('PRIVATE KEY')) {
    return {
      keys: [],
      error: 'Private key detected! Please paste only public keys (e.g. ssh-ed25519, ssh-rsa).',
    }
  }

  const lines = trimmed.split('\n').map((l) => l.trim()).filter(Boolean)
  const keys: { type: string; comment: string; full: string }[] = []

  for (const line of lines) {
    if (line === 'auto') continue
    const parts = line.split(/\s+/)
    if (parts.length < 2) {
      return {
        keys: [],
        error: `Invalid key format: "${line.slice(0, 30)}..." (expected "<type> <base64-key> [comment]")`,
      }
    }
    const type = parts[0]
    if (!type.startsWith('ssh-') && !type.startsWith('ecdsa-') && !type.startsWith('sk-')) {
      return {
        keys: [],
        error: `Unsupported key type "${type}". Key must start with ssh-, ecdsa-, or sk-.`,
      }
    }
    if (line.includes("'")) {
      return {
        keys: [],
        error: "SSH key cannot contain single quotes (')",
      }
    }
    const comment = parts.slice(2).join(' ') || 'no comment'
    keys.push({ type, comment, full: line })
  }

  return { keys, error: null }
}

function validate(
  images: OsImage[],
  baseUrl: string,
  aptMirror: string,
  sshError: string | null
): string | null {
  if (images.length === 0) return 'Add at least one OS image'
  const seen = new Set<string>()
  for (const img of images) {
    const key = `${img.os_name}/${img.version}`
    if (seen.has(key)) return `Duplicate OS image ${key}`
    seen.add(key)
    if (!NFS_ROOT_RE.test(img.nfs_root.trim())) {
      return `NFS export for ${key} must look like host:/path`
    }
  }
  const cleanUrl = baseUrl.trim()
  if (cleanUrl) {
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      return 'iPXE Server URL must start with http:// or https://'
    }
    if (/\s/.test(cleanUrl)) {
      return 'iPXE Server URL cannot contain whitespace'
    }
  }
  const cleanMirror = aptMirror.trim()
  if (cleanMirror) {
    if (!cleanMirror.startsWith('http://') && !cleanMirror.startsWith('https://')) {
      return 'Ubuntu APT mirror URL must start with http:// or https://'
    }
    if (/\s/.test(cleanMirror)) {
      return 'Ubuntu APT mirror URL cannot contain whitespace'
    }
  }
  if (sshError) {
    return sshError
  }
  return null
}

export function SettingsDefaultsCard() {
  const { settings, save, fetchAssetsNow } = useSettings()
  const [form, setForm] = useState<Form | null>(null)
  const [saving, setSaving] = useState(false)
  const [busyKey, setBusyKey] = useState<string | null>(null)
  const [browserOrigin, setBrowserOrigin] = useState('')
  const [testingMirror, setTestingMirror] = useState(false)
  const [mirrorTestResult, setMirrorTestResult] = useState<TestAptMirrorRes | null>(null)

  useEffect(() => {
    if (typeof window !== 'undefined') {
      setBrowserOrigin(window.location.origin)
    }
  }, [])

  const providers = settings?.providers ?? []

  // sync once when the first payload arrives; polling must not overwrite edits
  if (settings && form === null) {
    setForm({
      images: settings.os_images.map((img) => ({ ...img })),
      ssh_keys_default: settings.ssh_keys_default,
      base_url_override: settings.base_url_override,
      apt_mirror_default: settings.apt_mirror_default ?? '',
    })
  }

  function updateImage(idx: number, patch: Partial<OsImage>) {
    setForm((f) =>
      f ? { ...f, images: f.images.map((img, i) => (i === idx ? { ...img, ...patch } : img)) } : f
    )
  }

  function setDefault(idx: number) {
    setForm((f) =>
      f ? { ...f, images: f.images.map((img, i) => ({ ...img, is_default: i === idx })) } : f
    )
  }

  function removeImage(idx: number) {
    setForm((f) => {
      if (!f || f.images.length === 1) return f
      const wasDefault = f.images[idx].is_default
      const images = f.images.filter((_, i) => i !== idx)
      if (wasDefault) images[0] = { ...images[0], is_default: true }
      return { ...f, images }
    })
  }

  function addImage() {
    if (!form) return
    const used = new Set(form.images.map((img) => `${img.os_name}/${img.version}`))
    let pick: { os_name: string; version: string } | null = null
    for (const p of providers) {
      const version = p.versions.find((v) => !used.has(`${p.name}/${v}`))
      if (version) {
        pick = { os_name: p.name, version }
        break
      }
    }
    if (!pick) {
      toast.warning('All known OS images are already in the list')
      return
    }
    setForm({
      ...form,
      images: [...form.images, { ...pick, nfs_root: '', is_default: false }],
    })
  }

  async function onFetch(img: OsImage) {
    const key = `${img.os_name}/${img.version}`
    setBusyKey(key)
    try {
      await fetchAssetsNow({ os_name: img.os_name, version: img.version })
      toast.success(`Asset preparation started for ${imageLabel(img, providers)}`)
    } catch (err) {
      toast.error(apiErrorMessage(err))
    } finally {
      setBusyKey(null)
    }
  }

  async function onSave() {
    if (!form) return
    const parsedSsh = parseSshKeys(form.ssh_keys_default)
    const problem = validate(
      form.images,
      form.base_url_override,
      form.apt_mirror_default,
      parsedSsh.error
    )
    if (problem) {
      toast.warning(problem)
      return
    }
    setSaving(true)
    try {
      // If the user cleared the textarea, send 'auto' so backend resets the setting in DB
      const sshPayload =
        form.ssh_keys_default.trim() === '' ? 'auto' : form.ssh_keys_default.trim()
      const aptMirrorPayload =
        form.apt_mirror_default.trim() === '' ? 'default' : form.apt_mirror_default.trim()
      const res = await save({
        ssh_keys_default: sshPayload,
        base_url_override: form.base_url_override,
        apt_mirror_default: aptMirrorPayload,
        os_images: form.images.map((img) => ({ ...img, nfs_root: img.nfs_root.trim() })),
      })
      // resync from the response so server-side normalization (default row) shows up
      setForm({
        images: res.os_images.map((img) => ({ ...img })),
        ssh_keys_default: res.ssh_keys_default,
        base_url_override: res.base_url_override,
        apt_mirror_default: res.apt_mirror_default ?? '',
      })
      toast.success('Settings saved')
    } catch (err) {
      toast.error(apiErrorMessage(err))
    } finally {
      setSaving(false)
    }
  }

  const isDirty = computeIsDirty(form, settings)

  async function onTestMirror() {
    setTestingMirror(true)
    setMirrorTestResult(null)
    try {
      const res = await api<TestAptMirrorRes>('/api/settings/test-apt-mirror', {
        method: 'POST',
        body: JSON.stringify({ url: form?.apt_mirror_default || 'default' }),
      })
      setMirrorTestResult(res)
      if (res.ok) {
        toast.success(res.message)
      } else {
        toast.error(res.message)
      }
    } catch (err) {
      toast.error(apiErrorMessage(err))
    } finally {
      setTestingMirror(false)
    }
  }

  function onDiscard() {
    if (!settings) return
    setMirrorTestResult(null)
    setForm({
      images: settings.os_images.map((img) => ({ ...img })),
      ssh_keys_default: settings.ssh_keys_default,
      base_url_override: settings.base_url_override,
      apt_mirror_default: settings.apt_mirror_default ?? '',
    })
    toast.info('Changes discarded')
  }

  const rawBaseUrl = form?.base_url_override?.trim() ?? ''
  const baseUrlError =
    rawBaseUrl && !rawBaseUrl.startsWith('http://') && !rawBaseUrl.startsWith('https://')
      ? 'URL must start with http:// or https://'
      : rawBaseUrl && /\s/.test(rawBaseUrl)
        ? 'URL cannot contain whitespace'
        : null

  const rawAptMirror = form?.apt_mirror_default?.trim() ?? ''
  const aptMirrorError =
    rawAptMirror && !rawAptMirror.startsWith('http://') && !rawAptMirror.startsWith('https://')
      ? 'Mirror URL must start with http:// or https://'
      : rawAptMirror && /\s/.test(rawAptMirror)
        ? 'Mirror URL cannot contain whitespace'
        : null

  const parsedSsh = parseSshKeys(form?.ssh_keys_default ?? '')

  return (
    <Card>
      <CardHeader className="border-b bg-muted/15 px-6 py-4">
        <CardTitle className="text-lg font-semibold tracking-tight">Global Configuration</CardTitle>
        <CardDescription>
          Manage OS installation images, server network endpoint, and global SSH credentials.
        </CardDescription>
      </CardHeader>
      <CardContent className="grid gap-6 p-6">
        <div className="grid gap-3">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <Label className="text-sm font-semibold">OS images</Label>
              <p className="text-xs text-muted-foreground">
                Machines pick one of these images to install. The star marks the image used for newly
                discovered machines; the NFS export is inherited unless a machine defines its own.
              </p>
            </div>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={addImage}
              disabled={!form || providers.length === 0}
            >
              <PlusIcon data-icon="inline-start" />
              Add image
            </Button>
          </div>

          <div className="rounded-lg border overflow-hidden bg-card">
            <Table>
              <TableHeader className="bg-muted/40">
                <TableRow>
                  <TableHead className="w-[250px]">OS & Version</TableHead>
                  <TableHead>NFS Root Export</TableHead>
                  <TableHead className="w-[190px]">Boot Assets</TableHead>
                  <TableHead className="w-[80px] text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {form?.images.map((img, idx) => {
                  const key = `${img.os_name}/${img.version}`
                  const provider = providers.find((p) => p.name === img.os_name)
                  const osOptions = osOptionsFor(providers, img)
                  const versionOptions = versionOptionsFor(provider, img)
                  const asset = settings?.assets?.find(
                    (a) => a.os_name === img.os_name && a.version === img.version
                  )
                  const phase: AssetPhase = asset?.phase ?? 'idle'
                  const badge = PHASE_BADGES[phase]
                  const PhaseIcon = PHASE_ICONS[phase]
                  const busy = busyKey === key
                  const canFetch = phase === 'idle' || phase === 'failed'

                  return (
                    <TableRow key={idx}>
                      <TableCell className="align-middle py-3">
                        <div className="flex flex-wrap items-center gap-1.5">
                          <Select
                            items={osOptions}
                            value={img.os_name}
                            onValueChange={(value) => {
                              if (typeof value !== 'string') return
                              const picked = providers.find((p) => p.name === value)
                              updateImage(idx, {
                                os_name: value,
                                version: picked?.versions[0] ?? img.version,
                              })
                            }}
                          >
                            <SelectTrigger className="w-32 h-8 text-xs" aria-label="OS">
                              <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                              {osOptions.map((option) => (
                                <SelectItem
                                  key={option.value}
                                  value={option.value}
                                  disabled={option.disabled}
                                >
                                  {option.label}
                                </SelectItem>
                              ))}
                            </SelectContent>
                          </Select>
                          <Select
                            items={versionOptions}
                            value={img.version}
                            onValueChange={(value) => {
                              if (typeof value === 'string') updateImage(idx, { version: value })
                            }}
                          >
                            <SelectTrigger className="w-24 h-8 text-xs" aria-label="Version">
                              <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                              {versionOptions.map((option) => (
                                <SelectItem
                                  key={option.value}
                                  value={option.value}
                                  disabled={option.disabled}
                                >
                                  {option.label}
                                </SelectItem>
                              ))}
                            </SelectContent>
                          </Select>
                        </div>
                      </TableCell>
                      <TableCell className="align-middle py-3">
                        <Input
                          value={img.nfs_root}
                          onChange={(e) => updateImage(idx, { nfs_root: e.target.value })}
                          placeholder={`192.168.250.4:/srv/nfs/${img.os_name}-${img.version}`}
                          className="font-mono text-xs sm:text-sm h-8"
                          aria-label="NFS export"
                        />
                      </TableCell>
                      <TableCell className="align-middle py-3">
                        <div className="flex items-center gap-2">
                          <Badge variant={badge.variant} className={badge.className}>
                            <PhaseIcon data-icon="inline-start" className="size-3" />
                            {phase}
                          </Badge>
                          {canFetch && (
                            <Button
                              type="button"
                              size="sm"
                              variant="outline"
                              className="h-7 text-xs px-2"
                              onClick={() => onFetch(img)}
                              disabled={busy}
                              title="Fetch installer assets (kernel & initrd)"
                            >
                              {busy ? (
                                <Loader2Icon className="size-3 animate-spin" />
                              ) : (
                                <CloudDownloadIcon className="size-3" />
                              )}
                              Fetch
                            </Button>
                          )}
                        </div>
                        {(phase === 'downloading' || phase === 'extracting') && (
                          <div className="mt-1.5 w-32">
                            <Progress value={asset?.percent ?? 0} className="h-1.5" />
                            <div className="flex justify-between text-[10px] text-muted-foreground mt-0.5">
                              <span>{phase}</span>
                              <span>{asset?.percent ?? 0}%</span>
                            </div>
                          </div>
                        )}
                      </TableCell>
                      <TableCell className="text-right align-middle py-3">
                        <div className="flex items-center justify-end gap-1">
                          <Button
                            type="button"
                            variant="ghost"
                            size="icon-sm"
                            aria-label="Set as default image"
                            title={
                              img.is_default
                                ? 'Default image for new machines'
                                : 'Set as default image'
                            }
                            onClick={() => setDefault(idx)}
                          >
                            <StarIcon
                              className={
                                img.is_default
                                  ? 'fill-amber-400 text-amber-500'
                                  : 'text-muted-foreground'
                              }
                            />
                          </Button>
                          <Button
                            type="button"
                            variant="ghost"
                            size="icon-sm"
                            aria-label="Remove image"
                            disabled={(form?.images.length ?? 0) <= 1}
                            onClick={() => removeImage(idx)}
                            className="text-muted-foreground hover:text-destructive"
                          >
                            <Trash2Icon />
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  )
                })}
              </TableBody>
            </Table>
          </div>
        </div>

        <div className="grid gap-2.5 rounded-lg border p-3.5 bg-card">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <div className="flex items-center gap-2">
                <Label htmlFor="settings-base-url" className="text-sm font-semibold">
                  iPXE Server URL
                </Label>
                <Badge variant={form?.base_url_override?.trim() ? 'default' : 'secondary'}>
                  {form?.base_url_override?.trim() ? 'Manual override' : 'Auto-detect'}
                </Badge>
              </div>
              <p className="text-xs text-muted-foreground mt-0.5">
                The HTTP address client machines use to download boot scripts and installer assets.
              </p>
            </div>

            <div className="flex items-center gap-1.5">
              {browserOrigin && (
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={() =>
                    setForm((f) => (f ? { ...f, base_url_override: browserOrigin } : f))
                  }
                  disabled={form?.base_url_override === browserOrigin}
                  title={`Set to current browser address (${browserOrigin})`}
                >
                  <LaptopIcon data-icon="inline-start" />
                  Use browser address
                </Button>
              )}
              {form?.base_url_override && (
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  onClick={() => setForm((f) => (f ? { ...f, base_url_override: '' } : f))}
                  title="Clear override to auto-detect from client request Host"
                >
                  <RotateCcwIcon data-icon="inline-start" />
                  Reset to auto
                </Button>
              )}
            </div>
          </div>

          <div className="grid gap-1">
            <Input
              id="settings-base-url"
              value={form?.base_url_override ?? ''}
              onChange={(e) =>
                setForm((f) => (f ? { ...f, base_url_override: e.target.value } : f))
              }
              placeholder={
                browserOrigin
                  ? `e.g. ${browserOrigin} (leave empty for auto-detect)`
                  : 'http://192.168.250.x:4793 (empty = auto-detect)'
              }
              className={`font-mono text-sm ${baseUrlError ? 'border-destructive focus-visible:ring-destructive' : ''}`}
            />
            <div className="flex items-center justify-between text-xs">
              {baseUrlError ? (
                <span className="text-destructive font-medium">{baseUrlError}</span>
              ) : form?.base_url_override?.trim() ? (
                <span className="text-muted-foreground">
                  Client machines will connect strictly to this URL.
                </span>
              ) : (
                <span className="text-muted-foreground">
                  Auto-detect mode: server dynamically resolves from the client request Host header
                  {browserOrigin ? ` (currently ${browserOrigin})` : ''}.
                </span>
              )}
            </div>
          </div>
        </div>

        <div className="grid gap-2.5 rounded-lg border p-3.5 bg-card">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <div className="flex flex-wrap items-center gap-2">
                <Label htmlFor="settings-apt-mirror" className="text-sm font-semibold">
                  Ubuntu APT Mirror URL
                </Label>
                <Badge variant={form?.apt_mirror_default?.trim() ? 'default' : 'secondary'}>
                  {form?.apt_mirror_default?.trim() ? 'Custom Mirror' : 'Default (Canonical)'}
                </Badge>
                {mirrorTestResult && (
                  <Badge
                    variant={mirrorTestResult.ok ? 'outline' : 'destructive'}
                    className={
                      mirrorTestResult.ok
                        ? 'text-emerald-600 dark:text-emerald-400 bg-emerald-500/10 border-emerald-500/20 text-xs font-mono gap-1'
                        : 'text-xs gap-1'
                    }
                  >
                    {mirrorTestResult.ok ? (
                      <CircleCheckIcon className="size-3 text-emerald-500" />
                    ) : (
                      <CircleXIcon className="size-3" />
                    )}
                    {mirrorTestResult.message}
                  </Badge>
                )}
              </div>
              <p className="text-xs text-muted-foreground mt-0.5">
                Package repository for autoinstall packages and /etc/apt/sources.list.d/ubuntu.sources post-install.
              </p>
            </div>

            <div className="flex flex-wrap items-center gap-1.5">
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={onTestMirror}
                disabled={testingMirror}
                title="Test connection and response time from server to this mirror"
                className="gap-1.5"
              >
                {testingMirror ? (
                  <Loader2Icon data-icon="inline-start" className="size-3.5 animate-spin" />
                ) : (
                  <ActivityIcon data-icon="inline-start" className="size-3.5 text-blue-500" />
                )}
                <span>Test Mirror</span>
              </Button>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => {
                  setMirrorTestResult(null)
                  setForm((f) =>
                    f ? { ...f, apt_mirror_default: 'http://vn.archive.ubuntu.com/ubuntu/' } : f
                  )
                }}
                disabled={form?.apt_mirror_default?.trim() === 'http://vn.archive.ubuntu.com/ubuntu/'}
                title="Use fast Vietnam archive mirror (ping < 10ms)"
              >
                Mirror VN
              </Button>
              {form?.apt_mirror_default && (
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  onClick={() => {
                    setMirrorTestResult(null)
                    setForm((f) => (f ? { ...f, apt_mirror_default: '' } : f))
                  }}
                  title="Reset to official Canonical default (archive.ubuntu.com)"
                >
                  <RotateCcwIcon data-icon="inline-start" />
                  Default (Canonical)
                </Button>
              )}
            </div>
          </div>

          <div className="grid gap-1">
            <Input
              id="settings-apt-mirror"
              value={form?.apt_mirror_default ?? ''}
              onChange={(e) => {
                setMirrorTestResult(null)
                setForm((f) => (f ? { ...f, apt_mirror_default: e.target.value } : f))
              }}
              placeholder="http://archive.ubuntu.com/ubuntu/ (empty = Canonical default)"
              className={`font-mono text-sm ${aptMirrorError ? 'border-destructive focus-visible:ring-destructive' : ''}`}
            />
            <div className="flex items-center justify-between text-xs">
              {aptMirrorError ? (
                <span className="text-destructive font-medium">{aptMirrorError}</span>
              ) : form?.apt_mirror_default?.trim() ? (
                <span className="text-muted-foreground">
                  Machines will use this custom mirror for all apt repositories and security updates.
                </span>
              ) : (
                <span className="text-muted-foreground">
                  Default mode: uses Canonical official archive. Click &quot;Mirror VN&quot; for high-speed local mirror.
                </span>
              )}
            </div>
          </div>
        </div>

        <div className="grid gap-2.5 rounded-lg border p-3.5 bg-card">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <div className="flex items-center gap-2">
                <Label htmlFor="settings-ssh-keys" className="text-sm font-semibold">
                  Global SSH authorized keys
                </Label>
                <Badge variant={parsedSsh.keys.length > 0 ? 'secondary' : 'outline'}>
                  <KeyRoundIcon data-icon="inline-start" className="size-3" />
                  {parsedSsh.keys.length} {parsedSsh.keys.length === 1 ? 'key' : 'keys'}
                </Badge>
              </div>
              <p className="text-xs text-muted-foreground mt-0.5">
                Public keys injected into newly installed machines. Per-machine keys can override these.
              </p>
            </div>

            {form?.ssh_keys_default?.trim() && (
              <Button
                type="button"
                variant="ghost"
                size="sm"
                onClick={() => setForm((f) => (f ? { ...f, ssh_keys_default: '' } : f))}
                title="Clear all global SSH keys"
              >
                <Trash2Icon data-icon="inline-start" />
                Clear keys
              </Button>
            )}
          </div>

          {parsedSsh.keys.length > 0 && (
            <div className="flex flex-wrap gap-1.5 pt-0.5">
              {parsedSsh.keys.map((k, i) => (
                <Badge
                  key={i}
                  variant="outline"
                  className="font-mono text-xs font-normal py-0.5 px-2 bg-muted/30"
                >
                  <span className="font-semibold text-primary mr-1.5">{k.type}</span>
                  <span className="text-muted-foreground truncate max-w-[240px]">{k.comment}</span>
                </Badge>
              ))}
            </div>
          )}

          <div className="grid gap-1">
            <Textarea
              id="settings-ssh-keys"
              value={form?.ssh_keys_default ?? ''}
              onChange={(e) =>
                setForm((f) => (f ? { ...f, ssh_keys_default: e.target.value } : f))
              }
              rows={Math.min(6, Math.max(3, (form?.ssh_keys_default ?? '').split('\n').length))}
              placeholder="Paste public keys here (one per line, e.g. ssh-ed25519 AAAA... user@host)"
              className={`font-mono text-xs ${parsedSsh.error ? 'border-destructive focus-visible:ring-destructive' : ''}`}
            />
            <div className="flex items-center justify-between text-xs">
              {parsedSsh.error ? (
                <span className="text-destructive font-medium">{parsedSsh.error}</span>
              ) : form?.ssh_keys_default?.trim() ? (
                <span className="text-muted-foreground">
                  One key per line. Comment at the end of each key identifies the owner.
                </span>
              ) : (
                <span className="text-muted-foreground">
                  No default keys configured. Leave empty if you don&apos;t want default SSH access.
                </span>
              )}
            </div>
          </div>
        </div>
      </CardContent>
      <CardFooter className="flex flex-wrap items-center justify-between gap-3 border-t bg-muted/15 px-6 py-4">
        <div className="flex items-center gap-2 text-xs">
          {isDirty ? (
            <span className="flex items-center gap-1.5 font-medium text-amber-600 dark:text-amber-400">
              <span className="size-2 rounded-full bg-amber-500 animate-pulse" />
              You have unsaved changes
            </span>
          ) : (
            <span className="flex items-center gap-1.5 text-muted-foreground">
              <CircleCheckIcon className="size-3.5 text-green-600 dark:text-green-400" />
              All settings are up to date
            </span>
          )}
        </div>

        <div className="flex items-center gap-2">
          {isDirty && (
            <Button
              type="button"
              variant="outline"
              className="h-10 pl-3.5 pr-4 gap-2 text-sm inline-flex items-center justify-center"
              onClick={onDiscard}
              disabled={saving}
            >
              <RotateCcwIcon className="size-4 shrink-0" />
              <span className="leading-none">Discard</span>
            </Button>
          )}
          <Button
            onClick={onSave}
            disabled={saving || !form || !isDirty}
            className="h-10 pl-3.5 pr-4.5 gap-2 text-sm font-semibold shadow-sm inline-flex items-center justify-center text-center"
          >
            {saving ? (
              <Loader2Icon className="size-4 animate-spin shrink-0" />
            ) : (
              <SaveIcon className="size-4 shrink-0" />
            )}
            <span className="leading-none">Save changes</span>
          </Button>
        </div>
      </CardFooter>
    </Card>
  )
}

'use client'

import { useState } from 'react'
import { Loader2Icon, PlusIcon, SaveIcon, StarIcon, Trash2Icon } from 'lucide-react'
import { toast } from 'sonner'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Textarea } from '@/components/ui/textarea'
import { useSettings } from '@/hooks/use-settings'
import { apiErrorMessage } from '@/lib/api'
import type { OsImage, ProviderInfo } from '@/lib/types'

interface Form {
  images: OsImage[]
  ssh_keys_default: string
  base_url_override: string
}

interface SelectOption {
  value: string
  label: string
  disabled?: boolean
}

const NFS_ROOT_RE = /^[^\s:]+:\/.+$/

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

function validate(images: OsImage[]): string | null {
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
  return null
}

export function SettingsDefaultsCard() {
  const { settings, save } = useSettings()
  const [form, setForm] = useState<Form | null>(null)
  const [saving, setSaving] = useState(false)

  const providers = settings?.providers ?? []

  // sync once when the first payload arrives; polling must not overwrite edits
  if (settings && form === null) {
    setForm({
      images: settings.os_images.map((img) => ({ ...img })),
      ssh_keys_default: settings.ssh_keys_default,
      base_url_override: settings.base_url_override,
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

  async function onSave() {
    if (!form) return
    const problem = validate(form.images)
    if (problem) {
      toast.warning(problem)
      return
    }
    setSaving(true)
    try {
      const res = await save({
        ssh_keys_default: form.ssh_keys_default,
        base_url_override: form.base_url_override,
        os_images: form.images.map((img) => ({ ...img, nfs_root: img.nfs_root.trim() })),
      })
      // resync from the response so server-side normalization (default row) shows up
      setForm({
        images: res.os_images.map((img) => ({ ...img })),
        ssh_keys_default: res.ssh_keys_default,
        base_url_override: res.base_url_override,
      })
      toast.success('Settings saved')
    } catch (err) {
      toast.error(apiErrorMessage(err))
    } finally {
      setSaving(false)
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Defaults</CardTitle>
      </CardHeader>
      <CardContent className="grid gap-4">
        <div className="grid gap-3">
          <div>
            <Label>OS images</Label>
            <p className="text-xs text-muted-foreground">
              Machines pick one of these images to install. The star marks the image used for newly
              discovered machines; the NFS export is inherited unless a machine defines its own.
            </p>
          </div>
          {form?.images.map((img, idx) => {
            const provider = providers.find((p) => p.name === img.os_name)
            const osOptions = osOptionsFor(providers, img)
            const versionOptions = versionOptionsFor(provider, img)
            return (
              <div key={idx} className="grid gap-2 rounded-lg border p-3">
                <div className="flex items-center gap-2">
                  <Select
                    items={osOptions}
                    value={img.os_name}
                    onValueChange={(value) => {
                      if (typeof value !== 'string') return
                      const picked = providers.find((p) => p.name === value)
                      updateImage(idx, { os_name: value, version: picked?.versions[0] ?? img.version })
                    }}
                  >
                    <SelectTrigger className="flex-1" aria-label="OS">
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
                    <SelectTrigger className="w-28" aria-label="Version">
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
                  {img.is_default && <Badge variant="secondary">default</Badge>}
                  <Button
                    type="button"
                    variant="ghost"
                    size="icon-sm"
                    aria-label="Set as default image"
                    title="Use this image for new machines"
                    onClick={() => setDefault(idx)}
                  >
                    <StarIcon className={img.is_default ? 'fill-current' : ''} />
                  </Button>
                  <Button
                    type="button"
                    variant="ghost"
                    size="icon-sm"
                    aria-label="Remove image"
                    disabled={(form?.images.length ?? 0) <= 1}
                    onClick={() => removeImage(idx)}
                  >
                    <Trash2Icon />
                  </Button>
                </div>
                <Input
                  value={img.nfs_root}
                  onChange={(e) => updateImage(idx, { nfs_root: e.target.value })}
                  placeholder={`192.168.250.4:/srv/nfs/${img.os_name}-${img.version}`}
                  className="font-mono"
                  aria-label="NFS export"
                />
              </div>
            )
          })}
          <Button
            type="button"
            variant="outline"
            size="sm"
            className="justify-self-start"
            onClick={addImage}
            disabled={!form || providers.length === 0}
          >
            <PlusIcon data-icon="inline-start" />
            Add image
          </Button>
        </div>
        <div className="grid gap-1.5">
          <Label htmlFor="settings-base-url">Base URL override</Label>
          <Input
            id="settings-base-url"
            value={form?.base_url_override ?? ''}
            onChange={(e) => setForm((f) => (f ? { ...f, base_url_override: e.target.value } : f))}
            placeholder="http://192.168.250.x:8080 (empty = use request Host)"
            className="font-mono"
          />
        </div>
        <div className="grid gap-1.5">
          <Label htmlFor="settings-ssh-keys">Global SSH authorized keys (one per line)</Label>
          <Textarea
            id="settings-ssh-keys"
            value={form?.ssh_keys_default ?? ''}
            onChange={(e) => setForm((f) => (f ? { ...f, ssh_keys_default: e.target.value } : f))}
            rows={3}
            placeholder="ssh-ed25519 AAAA... user@host"
            className="font-mono"
          />
          <p className="text-xs text-muted-foreground">
            Machines with no keys of their own inherit these. Type &quot;auto&quot; to clear them;
            leaving the field empty keeps the current value.
          </p>
        </div>
      </CardContent>
      <CardFooter className="justify-end">
        <Button onClick={onSave} disabled={saving || !form}>
          {saving ? (
            <Loader2Icon data-icon="inline-start" className="animate-spin" />
          ) : (
            <SaveIcon data-icon="inline-start" />
          )}
          Save settings
        </Button>
      </CardFooter>
    </Card>
  )
}

'use client'

import { useState } from 'react'
import {
  CircleCheckIcon,
  CircleXIcon,
  ClockIcon,
  CloudDownloadIcon,
  DownloadIcon,
  Loader2Icon,
  PackageOpenIcon,
  type LucideIcon,
} from 'lucide-react'
import { toast } from 'sonner'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Progress } from '@/components/ui/progress'
import { useSettings } from '@/hooks/use-settings'
import { apiErrorMessage } from '@/lib/api'
import { imageLabel } from '@/lib/os-images'
import type { AssetPhase, OsImage } from '@/lib/types'

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

export function SettingsAssetsCard() {
  const { settings, fetchAssetsNow } = useSettings()
  const [busyKey, setBusyKey] = useState<string | null>(null)
  const images = settings?.os_images ?? []
  const providers = settings?.providers ?? []

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

  return (
    <Card>
      <CardHeader>
        <CardTitle>Installer assets</CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        {images.length === 0 ? (
          <div className="text-sm text-muted-foreground">No OS images configured.</div>
        ) : (
          <div className="divide-y rounded-lg border">
            {images.map((img) => {
              const key = `${img.os_name}/${img.version}`
              const asset = settings?.assets.find(
                (a) => a.os_name === img.os_name && a.version === img.version
              )
              const phase: AssetPhase = asset?.phase ?? 'idle'
              const badge = PHASE_BADGES[phase]
              const PhaseIcon = PHASE_ICONS[phase]
              const busy = busyKey === key
              return (
                <div key={key} className="grid gap-2 px-3 py-3">
                  <div className="flex items-center justify-between gap-2">
                    <div className="flex items-center gap-2">
                      <span className="text-sm font-medium">{imageLabel(img, providers)}</span>
                      <Badge variant={badge.variant} className={badge.className}>
                        <PhaseIcon data-icon="inline-start" />
                        {phase}
                      </Badge>
                    </div>
                    <Button size="sm" onClick={() => onFetch(img)} disabled={busy}>
                      {busy ? (
                        <Loader2Icon data-icon="inline-start" className="animate-spin" />
                      ) : (
                        <CloudDownloadIcon data-icon="inline-start" />
                      )}
                      Fetch now
                    </Button>
                  </div>
                  <div className="text-sm text-muted-foreground">
                    {asset?.message || 'No asset operation yet.'}
                  </div>
                  {(phase === 'downloading' || phase === 'extracting') && (
                    <Progress value={asset?.percent ?? 0} />
                  )}
                </div>
              )
            })}
          </div>
        )}
        <dl className="divide-y rounded-lg border text-sm">
          <div className="grid grid-cols-[200px_1fr] gap-2 px-3 py-2">
            <dt className="text-muted-foreground">Extractors available</dt>
            <dd>
              {settings?.extractors.join(', ') || 'none (install xorriso / p7zip / libarchive)'}
            </dd>
          </div>
        </dl>
      </CardContent>
    </Card>
  )
}

'use client'

import { useEffect, useState } from 'react'
import { Check, Copy } from 'lucide-react'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import { useSettings } from '@/hooks/use-settings'

export function SettingsServerCard() {
  const { settings } = useSettings()
  const [copied, setCopied] = useState(false)
  const [browserOrigin, setBrowserOrigin] = useState('')

  useEffect(() => {
    if (typeof window !== 'undefined') {
      setBrowserOrigin(window.location.origin)
    }
  }, [])

  const rawBase = settings?.base_url_override?.trim()
  let baseUrl = rawBase
  if (!baseUrl && typeof window !== 'undefined' && browserOrigin) {
    if (settings?.system && !settings.system.unified_process) {
      const port = settings.system.backend.port || settings.system.port || 4793
      baseUrl = `${window.location.protocol}//${window.location.hostname}:${port}`
    } else {
      baseUrl = browserOrigin
    }
  }

  const cleanBase = baseUrl ? baseUrl.replace(/\/+$/, '') : 'http://…'
  const ipxeUrl = `${cleanBase}/boot.ipxe?mac=\${net0/mac}`

  const handleCopy = async () => {
    if (!baseUrl) return
    try {
      await navigator.clipboard.writeText(ipxeUrl)
      setCopied(true)
      toast.success('iPXE boot URL copied to clipboard')
      setTimeout(() => setCopied(false), 2000)
    } catch {
      toast.error('Failed to copy URL to clipboard')
    }
  }

  return (
    <Card>
      <CardHeader className="border-b bg-muted/15 px-6 py-4">
        <CardTitle className="text-lg font-semibold tracking-tight">Server</CardTitle>
        <CardDescription>
          Runtime environment paths and system tools available on this host.
        </CardDescription>
      </CardHeader>
      <CardContent className="p-6">
        <dl className="divide-y rounded-lg border text-sm">
          <div className="grid grid-cols-[200px_1fr] gap-2 px-3 py-2">
            <dt className="text-muted-foreground">Data directory</dt>
            <dd className="font-mono">{settings?.data_dir || '…'}</dd>
          </div>
          <div className="grid grid-cols-[200px_1fr] gap-2 px-3 py-2">
            <dt className="text-muted-foreground">Database</dt>
            <dd className="font-mono">{settings?.db_path || '…'}</dd>
          </div>
          <div className="grid grid-cols-[200px_1fr] gap-2 px-3 py-2">
            <dt className="text-muted-foreground">Extractors available</dt>
            <dd>
              {settings?.extractors?.join(', ') || 'none (install xorriso / p7zip / libarchive)'}
            </dd>
          </div>
          <div className="grid grid-cols-[200px_1fr] gap-2 px-3 py-2.5 items-start">
            <dt className="text-muted-foreground pt-1">iPXE boot URL</dt>
            <dd className="space-y-1.5 min-w-0">
              <div className="flex flex-wrap items-center gap-2">
                <span className="inline-block font-mono text-xs select-all break-all bg-muted/60 px-2.5 py-1 rounded border">
                  {ipxeUrl}
                </span>
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  className="h-6 px-2 shrink-0 gap-1 text-[11px]"
                  onClick={handleCopy}
                >
                  {copied ? (
                    <Check className="size-3 text-emerald-500" />
                  ) : (
                    <Copy className="size-3" />
                  )}
                  <span>{copied ? 'Copied' : 'Copy'}</span>
                </Button>
              </div>
              <p className="text-[11px] text-muted-foreground">
                Chainload entry point for DHCP/dnsmasq config (e.g.{' '}
                <code className="font-mono text-[10px] bg-muted px-1 py-0.5 rounded">
                  dhcp-boot=tag:ipxe,...
                </code>
                )
              </p>
            </dd>
          </div>
        </dl>
      </CardContent>
    </Card>
  )
}


'use client'

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
        </dl>
      </CardContent>
    </Card>
  )
}

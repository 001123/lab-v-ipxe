'use client'

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { useSettings } from '@/hooks/use-settings'

export function SettingsServerCard() {
  const { settings } = useSettings()

  return (
    <Card>
      <CardHeader>
        <CardTitle>Server</CardTitle>
      </CardHeader>
      <CardContent>
        <dl className="divide-y rounded-lg border text-sm">
          <div className="grid grid-cols-[200px_1fr] gap-2 px-3 py-2">
            <dt className="text-muted-foreground">Data directory</dt>
            <dd className="font-mono">{settings?.data_dir || '…'}</dd>
          </div>
          <div className="grid grid-cols-[200px_1fr] gap-2 px-3 py-2">
            <dt className="text-muted-foreground">Database</dt>
            <dd className="font-mono">{settings?.db_path || '…'}</dd>
          </div>
        </dl>
      </CardContent>
    </Card>
  )
}

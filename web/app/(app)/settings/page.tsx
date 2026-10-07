'use client'

import { useEffect } from 'react'
import { toast } from 'sonner'
import { SettingsAssetsCard } from '@/components/settings-assets-card'
import { SettingsDefaultsCard } from '@/components/settings-defaults-card'
import { SettingsServerCard } from '@/components/settings-server-card'
import { useSettings } from '@/hooks/use-settings'
import { apiErrorMessage } from '@/lib/api'

export default function SettingsPage() {
  const { error } = useSettings()

  useEffect(() => {
    if (error) toast.error(apiErrorMessage(error))
  }, [error])

  return (
    <div className="mx-auto flex max-w-[1200px] flex-col gap-4">
      <SettingsAssetsCard />
      <SettingsDefaultsCard />
      <SettingsServerCard />
    </div>
  )
}

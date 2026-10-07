'use client'

import useSWR from 'swr'
import { api, fetcher } from '@/lib/api'
import type { AssetFetchPayload, SettingsPayload, SettingsRes } from '@/lib/types'

export function useSettings() {
  const { data, error, isLoading, mutate } = useSWR<SettingsRes>('/api/settings', fetcher, {
    refreshInterval: (settings) =>
      settings &&
      settings.assets.some((a) => a.phase === 'downloading' || a.phase === 'extracting')
        ? 2000
        : 0,
  })

  async function save(payload: SettingsPayload) {
    const res = await api<SettingsRes>('/api/settings', {
      method: 'PUT',
      body: JSON.stringify(payload),
    })
    await mutate(res, { revalidate: false })
    return res
  }

  async function fetchAssetsNow(payload: AssetFetchPayload = {}) {
    const res = await api<SettingsRes>('/api/assets/fetch', {
      method: 'POST',
      body: JSON.stringify(payload),
    })
    await mutate(res, { revalidate: false })
    return res
  }

  return { settings: data, loading: isLoading, error, mutate, save, fetchAssetsNow }
}

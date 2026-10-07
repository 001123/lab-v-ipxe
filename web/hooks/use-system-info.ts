'use client'

import useSWR from 'swr'
import { fetcher } from '@/lib/api'
import type { SystemInfo } from '@/lib/types'

export function formatRam(bytes: number): string {
  if (!bytes || bytes <= 0) return '—'
  const mb = bytes / (1024 * 1024)
  if (mb < 1024) {
    return `${mb.toFixed(1)} MB`
  }
  return `${(mb / 1024).toFixed(2)} GB`
}

export function useSystemInfo(refreshInterval = 10000) {
  const { data, error, isLoading, mutate } = useSWR<SystemInfo>(
    '/api/system/info',
    fetcher,
    {
      refreshInterval,
      revalidateOnFocus: true,
      dedupingInterval: 3000,
    },
  )

  const isUnified = data?.unified_process ?? false
  const beMem = data?.backend?.memory_bytes ?? 0
  const feMem = data?.frontend?.memory_bytes ?? 0
  const totalMem = isUnified ? beMem : beMem + feMem

  return {
    system: data,
    totalMem,
    beMem,
    feMem,
    isUnified,
    loading: isLoading,
    error,
    mutate,
  }
}

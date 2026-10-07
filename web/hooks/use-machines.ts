'use client'

import useSWR from 'swr'
import { api, fetcher } from '@/lib/api'
import type { Machine, MachinePayload } from '@/lib/types'

export function useMachines(refreshInterval = 5000) {
  const { data, error, isLoading, mutate } = useSWR<Machine[]>('/api/machines', fetcher, {
    refreshInterval,
  })

  async function create(payload: MachinePayload) {
    const machine = await api<Machine>('/api/machines', {
      method: 'POST',
      body: JSON.stringify(payload),
    })
    await mutate()
    return machine
  }

  async function update(id: number, payload: MachinePayload) {
    const machine = await api<Machine>(`/api/machines/${id}`, {
      method: 'PUT',
      body: JSON.stringify(payload),
    })
    await mutate()
    return machine
  }

  async function approve(id: number, payload: MachinePayload) {
    const machine = await api<Machine>(`/api/machines/${id}/approve`, {
      method: 'POST',
      body: JSON.stringify(payload),
    })
    await mutate()
    return machine
  }

  async function reinstall(id: number) {
    const machine = await api<Machine>(`/api/machines/${id}/reinstall`, { method: 'POST' })
    await mutate()
    return machine
  }

  async function markInstalled(id: number) {
    const machine = await api<Machine>(`/api/machines/${id}/mark-installed`, { method: 'POST' })
    await mutate()
    return machine
  }

  async function remove(id: number) {
    await api(`/api/machines/${id}`, { method: 'DELETE' })
    await mutate()
  }

  const list = data ?? []
  return {
    list,
    loading: isLoading,
    error,
    pendingCount: list.filter((m) => m.status === 'pending').length,
    mutate,
    create,
    update,
    approve,
    reinstall,
    markInstalled,
    remove,
  }
}

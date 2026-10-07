import { defineStore } from 'pinia'
import { api } from '../api/client'
import type { Machine, MachinePayload, SettingsPayload, SettingsRes } from '../api/types'

export const useMachinesStore = defineStore('machines', {
  state: () => ({
    list: [] as Machine[],
    loading: false,
    settings: null as SettingsRes | null,
  }),
  getters: {
    pendingCount: (s) => s.list.filter((m) => m.status === 'pending').length,
  },
  actions: {
    async fetchList() {
      this.loading = true
      try {
        const { data } = await api.get<Machine[]>('/api/machines')
        this.list = data
      } finally {
        this.loading = false
      }
    },
    async create(payload: MachinePayload) {
      const { data } = await api.post<Machine>('/api/machines', payload)
      await this.fetchList()
      return data
    },
    async update(id: number, payload: MachinePayload) {
      const { data } = await api.put<Machine>(`/api/machines/${id}`, payload)
      await this.fetchList()
      return data
    },
    async approve(id: number, payload: MachinePayload) {
      const { data } = await api.post<Machine>(`/api/machines/${id}/approve`, payload)
      await this.fetchList()
      return data
    },
    async reinstall(id: number) {
      const { data } = await api.post<Machine>(`/api/machines/${id}/reinstall`)
      await this.fetchList()
      return data
    },
    async markInstalled(id: number) {
      const { data } = await api.post<Machine>(`/api/machines/${id}/mark-installed`)
      await this.fetchList()
      return data
    },
    async remove(id: number) {
      await api.delete(`/api/machines/${id}`)
      await this.fetchList()
    },
    async fetchSettings() {
      const { data } = await api.get<SettingsRes>('/api/settings')
      this.settings = data
      return data
    },
    async saveSettings(payload: SettingsPayload) {
      const { data } = await api.put<SettingsRes>('/api/settings', payload)
      this.settings = data
      return data
    },
    async fetchAssetsNow() {
      const { data } = await api.post<SettingsRes>('/api/assets/fetch')
      this.settings = data
      return data
    },
  },
})

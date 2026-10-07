import { defineStore } from 'pinia'
import { api, TOKEN_KEY } from '../api/client'
import type { LoginRes } from '../api/types'

export const useAuthStore = defineStore('auth', {
  state: () => ({
    token: localStorage.getItem(TOKEN_KEY) || '',
    email: '',
  }),
  getters: {
    isAuthed: (s) => s.token !== '',
  },
  actions: {
    async login(email: string, password: string) {
      const { data } = await api.post<LoginRes>('/api/auth/login', { email, password })
      this.token = data.token
      this.email = data.user.email
      localStorage.setItem(TOKEN_KEY, data.token)
    },
    async fetchMe() {
      const { data } = await api.get<{ email: string }>('/api/auth/me')
      this.email = data.email
    },
    async logout() {
      try {
        await api.post('/api/auth/logout')
      } catch {
        // token may already be invalid; clearing locally is what matters
      }
      this.token = ''
      this.email = ''
      localStorage.removeItem(TOKEN_KEY)
    },
  },
})

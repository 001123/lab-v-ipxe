'use client'

import { createContext, useCallback, useContext, useEffect, useState } from 'react'
import { useMounted } from '@/hooks/use-mounted'
import { api, getToken, TOKEN_KEY } from '@/lib/api'
import type { LoginRes } from '@/lib/types'

interface AuthValue {
  ready: boolean
  isAuthed: boolean
  email: string
  login: (email: string, password: string) => Promise<void>
  logout: () => Promise<void>
}

const AuthContext = createContext<AuthValue | null>(null)

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const ready = useMounted()
  const [token, setToken] = useState('')
  const [email, setEmail] = useState('')

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- localStorage is client-only; the token cannot be read before hydration
    setToken(getToken())
  }, [])

  useEffect(() => {
    if (!token || email) return
    let cancelled = false
    api<{ email: string }>('/api/auth/me')
      .then((res) => {
        if (!cancelled) setEmail(res.email)
      })
      .catch(() => {
        // the api() 401 handler redirects to /login
      })
    return () => {
      cancelled = true
    }
  }, [token, email])

  const login = useCallback(async (email: string, password: string) => {
    const res = await api<LoginRes>('/api/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    })
    localStorage.setItem(TOKEN_KEY, res.token)
    setToken(res.token)
    setEmail(res.user.email)
  }, [])

  const logout = useCallback(async () => {
    try {
      await api('/api/auth/logout', { method: 'POST' })
    } catch {
      // token may already be invalid; clearing locally is what matters
    }
    setToken('')
    setEmail('')
    localStorage.removeItem(TOKEN_KEY)
  }, [])

  return (
    <AuthContext.Provider value={{ ready, isAuthed: token !== '', email, login, logout }}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth(): AuthValue {
  const value = useContext(AuthContext)
  if (!value) throw new Error('useAuth must be used within AuthProvider')
  return value
}

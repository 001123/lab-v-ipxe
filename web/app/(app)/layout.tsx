'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { AppShell } from '@/components/app-shell'
import { useAuth } from '@/hooks/use-auth'

export default function AppLayout({ children }: { children: React.ReactNode }) {
  const { ready, isAuthed } = useAuth()
  const router = useRouter()

  useEffect(() => {
    if (ready && !isAuthed) {
      router.replace('/login')
    }
  }, [ready, isAuthed, router])

  if (!ready || !isAuthed) {
    return null
  }

  return <AppShell>{children}</AppShell>
}

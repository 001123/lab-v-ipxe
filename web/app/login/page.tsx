'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { EyeIcon, EyeOffIcon, Loader2Icon, LogInIcon, NetworkIcon } from 'lucide-react'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import { Card, CardAction, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { useAuth } from '@/hooks/use-auth'
import { apiErrorMessage } from '@/lib/api'

export default function LoginPage() {
  const router = useRouter()
  const { ready, isAuthed, login } = useAuth()
  const [email, setEmail] = useState('admin@ipxe.local')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    if (ready && isAuthed) {
      router.replace('/machines')
    }
  }, [ready, isAuthed, router])

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!email || !password) {
      toast.warning('Enter email and password')
      return
    }
    setLoading(true)
    try {
      await login(email, password)
      router.push('/machines')
    } catch (err) {
      toast.error(apiErrorMessage(err))
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="flex min-h-dvh items-center justify-center bg-[linear-gradient(135deg,#0f172a_0%,#1e3a5f_100%)] p-4">
      <Card className="w-[380px]">
        <CardHeader>
          <NetworkIcon className="size-6" />
          <CardTitle>lab-v-ipxe</CardTitle>
          <CardAction className="self-center text-xs opacity-60">
            ZTP provisioning server
          </CardAction>
        </CardHeader>
        <CardContent>
          <form onSubmit={onSubmit} className="flex flex-col gap-4">
            <div className="grid gap-1.5">
              <Label htmlFor="email">Email</Label>
              <Input
                id="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="admin@ipxe.local"
                autoComplete="username"
              />
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor="password">Password</Label>
              <div className="relative">
                <Input
                  id="password"
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="password"
                  autoComplete="current-password"
                  className="pr-9"
                />
                <Button
                  type="button"
                  variant="ghost"
                  size="icon-sm"
                  className="absolute top-0.5 right-0.5"
                  onClick={() => setShowPassword((v) => !v)}
                  aria-label={showPassword ? 'Hide password' : 'Show password'}
                >
                  {showPassword ? <EyeOffIcon /> : <EyeIcon />}
                </Button>
              </div>
            </div>
            <Button type="submit" disabled={loading} className="w-full">
              {loading ? (
                <Loader2Icon data-icon="inline-start" className="animate-spin" />
              ) : (
                <LogInIcon data-icon="inline-start" />
              )}
              Sign in
            </Button>
          </form>
        </CardContent>
      </Card>
    </div>
  )
}

'use client'

import Link from 'next/link'
import { usePathname, useRouter } from 'next/navigation'
import { LogOutIcon, NetworkIcon, ServerIcon, SettingsIcon } from 'lucide-react'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { ThemeToggle } from '@/components/theme-toggle'
import { useAuth } from '@/hooks/use-auth'
import { useMachines } from '@/hooks/use-machines'
import { cn } from '@/lib/utils'

export function AppShell({ children }: { children: React.ReactNode }) {
  const { email, logout } = useAuth()
  const { pendingCount } = useMachines(0)
  const pathname = usePathname()
  const router = useRouter()

  const navItems = [
    {
      href: '/machines',
      label: pendingCount > 0 ? `Machines (${pendingCount} pending)` : 'Machines',
      icon: ServerIcon,
    },
    { href: '/settings', label: 'Settings', icon: SettingsIcon },
  ]

  async function onLogout() {
    await logout()
    router.push('/login')
  }

  return (
    <div className="flex min-h-dvh flex-col">
      <header className="flex h-14 shrink-0 items-center gap-4 border-b px-5">
        <div className="flex items-center gap-2 text-base font-semibold">
          <NetworkIcon className="size-5" />
          lab-v-ipxe
        </div>
        <Badge variant="secondary">ZTP provisioning</Badge>
        <div className="flex-1" />
        <span className="text-[13px] text-muted-foreground">{email}</span>
        <ThemeToggle />
        <Button variant="ghost" size="sm" onClick={onLogout}>
          <LogOutIcon data-icon="inline-start" />
          Logout
        </Button>
      </header>
      <div className="flex flex-1">
        <aside className="w-[200px] shrink-0 border-r py-3">
          <nav className="flex flex-col gap-0.5 px-2">
            {navItems.map(({ href, label, icon: Icon }) => (
              <Link
                key={href}
                href={href}
                // prefetch is broken with `output: export` (vercel/next.js#92341);
                // clicks still navigate client-side via the RSC payload
                prefetch={false}
                className={cn(
                  'flex items-center gap-2 rounded-md px-3 py-2 text-sm transition-colors',
                  pathname === href
                    ? 'bg-muted font-medium text-foreground'
                    : 'text-muted-foreground hover:bg-muted hover:text-foreground',
                )}
              >
                <Icon className="size-4" />
                {label}
              </Link>
            ))}
          </nav>
        </aside>
        <main className="min-w-0 flex-1 p-6">{children}</main>
      </div>
    </div>
  )
}

'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import { usePathname, useRouter } from 'next/navigation'
import { LogOutIcon, MenuIcon, NetworkIcon, ServerIcon, SettingsIcon } from 'lucide-react'
import { Button } from '@/components/ui/button'
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from '@/components/ui/sheet'
import { ThemeSegmentedToggle, ThemeToggle } from '@/components/theme-toggle'
import { useAuth } from '@/hooks/use-auth'
import { useMachines } from '@/hooks/use-machines'
import { formatRam, useSystemInfo } from '@/hooks/use-system-info'
import { cn } from '@/lib/utils'

export function AppShell({ children }: { children: React.ReactNode }) {
  const { email, logout } = useAuth()
  const { pendingCount } = useMachines(0)
  const { totalMem, beMem, feMem, isUnified, error: sysError } = useSystemInfo(10000)
  const pathname = usePathname()
  const router = useRouter()
  const [mobileOpen, setMobileOpen] = useState(false)

  const ramDisplay = sysError ? 'Offline' : totalMem > 0 ? formatRam(totalMem) : '—'
  const ramTooltip =
    totalMem > 0
      ? isUnified
        ? `App Process RSS: ${formatRam(totalMem)}`
        : `Total RSS: ${formatRam(totalMem)} (Backend: ${formatRam(beMem)}, Frontend: ${formatRam(feMem)})`
      : undefined

  // Close mobile navigation drawer when pathname changes
  useEffect(() => {
    setMobileOpen(false)
  }, [pathname])

  const navItems = [
    {
      href: '/machines',
      label: 'Machines',
      icon: ServerIcon,
      pending: pendingCount,
    },
    {
      href: '/settings',
      label: 'Settings',
      icon: SettingsIcon,
    },
  ]

  async function onLogout() {
    await logout()
    router.push('/login')
  }

  return (
    <div className="flex min-h-dvh flex-col bg-background">
      {/* Top Header */}
      <header className="sticky top-0 z-40 flex h-14 shrink-0 items-center justify-between border-b bg-background/95 px-4 backdrop-blur supports-backdrop-filter:bg-background/80 sm:px-6">
        <div className="flex items-center gap-3">
          {/* Mobile Menu Trigger Button */}
          <Button
            variant="ghost"
            size="icon-sm"
            className="md:hidden"
            onClick={() => setMobileOpen(true)}
            aria-label="Open navigation menu"
          >
            <div className="relative flex items-center justify-center">
              <MenuIcon className="size-5" />
              {pendingCount > 0 && (
                <span className="absolute -top-1 -right-1 size-2 rounded-full bg-amber-500 ring-2 ring-background" />
              )}
            </div>
          </Button>

          {/* Logo & Brand */}
          <Link
            href="/machines"
            className="flex items-center gap-2.5 font-semibold text-foreground tracking-tight hover:opacity-90 transition-opacity"
          >
            <div className="flex size-7 items-center justify-center rounded-md bg-primary/10 text-primary">
              <NetworkIcon className="size-4" />
            </div>
            <span className="font-semibold text-sm sm:text-base">iPXE ZTP</span>
          </Link>
        </div>

        {/* Header Right Actions */}
        <div className="flex items-center gap-2 sm:gap-3">
          {email && (
            <span className="hidden lg:inline-block font-mono text-xs text-muted-foreground bg-muted/60 px-2.5 py-1 rounded-md border border-border/50">
              {email}
            </span>
          )}
          <ThemeToggle />
          <Button
            variant="ghost"
            size="sm"
            onClick={onLogout}
            className="hidden md:inline-flex text-muted-foreground hover:text-foreground"
          >
            <LogOutIcon data-icon="inline-start" />
            Logout
          </Button>
        </div>
      </header>

      {/* Main Container */}
      <div className="flex flex-1">
        {/* Desktop Sidebar */}
        <aside className="hidden md:flex md:w-60 lg:w-64 shrink-0 flex-col justify-between border-r bg-sidebar/background py-4">
          <div className="flex flex-col">
            <div className="px-5 pb-2 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground/70">
              Navigation
            </div>
            <nav className="flex flex-col gap-1 px-3">
              {navItems.map(({ href, label, icon: Icon, pending }) => {
                const isActive = pathname === href
                return (
                  <Link
                    key={href}
                    href={href}
                    prefetch={false}
                    className={cn(
                      'group flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-all',
                      isActive
                        ? 'bg-secondary text-secondary-foreground shadow-xs font-semibold'
                        : 'text-muted-foreground hover:bg-muted/70 hover:text-foreground',
                    )}
                  >
                    <Icon
                      className={cn(
                        'size-4 shrink-0 transition-colors',
                        isActive ? 'text-primary' : 'text-muted-foreground group-hover:text-foreground',
                      )}
                    />
                    <span className="flex-1 truncate">{label}</span>
                    {pending && pending > 0 ? (
                      <span className="inline-flex items-center gap-1.5 rounded-full border border-amber-500/30 bg-amber-500/10 px-2 py-0.5 text-xs font-semibold text-amber-700 dark:text-amber-400 shrink-0 whitespace-nowrap">
                        <span className="size-1.5 rounded-full bg-amber-500 animate-pulse" />
                        <span>{pending} pending</span>
                      </span>
                    ) : null}
                  </Link>
                )
              })}
            </nav>
          </div>

          {/* Desktop Sidebar Status Indicator */}
          <div className="px-3 pt-4">
            <div
              className="rounded-lg border bg-muted/30 p-2.5 text-xs transition-colors hover:bg-muted/50"
              title={ramTooltip}
            >
              <div className="flex items-center justify-between font-medium">
                <span className="flex items-center gap-1.5 text-muted-foreground">
                  <span
                    className={cn(
                      'size-2 rounded-full',
                      sysError ? 'bg-destructive' : 'bg-emerald-500',
                    )}
                  />
                  Memory usage
                </span>
                <span className="text-[11px] font-mono font-medium text-foreground">
                  {ramDisplay}
                </span>
              </div>
            </div>
          </div>
        </aside>

        {/* Mobile Navigation Sheet Drawer */}
        <Sheet open={mobileOpen} onOpenChange={setMobileOpen}>
          <SheetContent side="left" className="w-[280px] sm:w-[320px] p-0 flex flex-col justify-between">
            <SheetHeader className="sr-only">
              <SheetTitle>Navigation Menu</SheetTitle>
              <SheetDescription>Mobile navigation links and user account</SheetDescription>
            </SheetHeader>

            <div className="flex flex-col">
              {/* Mobile Drawer Brand */}
              <div className="flex items-center gap-2.5 border-b p-4">
                <div className="flex size-8 items-center justify-center rounded-lg bg-primary/10 text-primary">
                  <NetworkIcon className="size-5" />
                </div>
                <div className="flex flex-col">
                  <span className="font-semibold text-sm leading-tight">iPXE ZTP</span>
                  <span className="text-[11px] text-muted-foreground">Provisioning server</span>
                </div>
              </div>

              {/* Mobile Nav Links */}
              <div className="px-3 py-4">
                <div className="px-2 pb-2 text-[11px] font-medium uppercase tracking-wider text-muted-foreground/70">
                  Navigation
                </div>
                <nav className="flex flex-col gap-1">
                  {navItems.map(({ href, label, icon: Icon, pending }) => {
                    const isActive = pathname === href
                    return (
                      <Link
                        key={href}
                        href={href}
                        prefetch={false}
                        onClick={() => setMobileOpen(false)}
                        className={cn(
                          'group flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors',
                          isActive
                            ? 'bg-secondary text-secondary-foreground shadow-xs font-semibold'
                            : 'text-muted-foreground hover:bg-muted/80 hover:text-foreground',
                        )}
                      >
                        <Icon
                          className={cn(
                            'size-4.5 shrink-0 transition-colors',
                            isActive ? 'text-primary' : 'text-muted-foreground',
                          )}
                        />
                        <span className="flex-1 truncate">{label}</span>
                        {pending && pending > 0 ? (
                          <span className="inline-flex items-center gap-1.5 rounded-full border border-amber-500/30 bg-amber-500/10 px-2 py-0.5 text-xs font-semibold text-amber-700 dark:text-amber-400 shrink-0 whitespace-nowrap">
                            <span className="size-1.5 rounded-full bg-amber-500 animate-pulse" />
                            <span>{pending} pending</span>
                          </span>
                        ) : null}
                      </Link>
                    )
                  })}
                </nav>
              </div>

              {/* Mobile Drawer Server Status */}
              <div className="px-3 pt-2">
                <div
                  className="rounded-lg border bg-muted/30 p-2.5 text-xs"
                  title={ramTooltip}
                >
                  <div className="flex items-center justify-between font-medium">
                    <span className="flex items-center gap-1.5 text-muted-foreground">
                      <span
                        className={cn(
                          'size-2 rounded-full',
                          sysError ? 'bg-destructive' : 'bg-emerald-500',
                        )}
                      />
                      Memory usage
                    </span>
                    <span className="text-[11px] font-mono font-medium text-foreground">
                      {ramDisplay}
                    </span>
                  </div>
                </div>
              </div>
            </div>

            {/* Mobile Drawer Footer */}
            <div className="mt-auto border-t p-4 flex flex-col gap-3 bg-muted/20">
              <div className="space-y-1">
                <div className="text-[11px] font-medium text-muted-foreground px-1">Theme</div>
                <ThemeSegmentedToggle />
              </div>
              {email && (
                <div className="flex items-center gap-2.5 px-1">
                  <div className="flex size-8 shrink-0 items-center justify-center rounded-full bg-muted font-medium text-xs text-foreground uppercase border">
                    {email.charAt(0)}
                  </div>
                  <div className="flex flex-col min-w-0 flex-1">
                    <span className="text-xs font-medium text-foreground truncate">{email}</span>
                    <span className="text-[11px] text-muted-foreground">Administrator</span>
                  </div>
                </div>
              )}
              <Button
                variant="outline"
                size="sm"
                className="w-full justify-start text-muted-foreground hover:text-destructive hover:border-destructive/30"
                onClick={() => {
                  setMobileOpen(false)
                  onLogout()
                }}
              >
                <LogOutIcon data-icon="inline-start" className="size-4" />
                Log out
              </Button>
            </div>
          </SheetContent>
        </Sheet>

        {/* Page Content */}
        <main className="min-w-0 flex-1 p-4 sm:p-6 lg:p-8">{children}</main>
      </div>
    </div>
  )
}


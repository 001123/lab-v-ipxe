'use client'

import { useTheme } from 'next-themes'
import { MonitorIcon, MoonIcon, SunIcon } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { useMounted } from '@/hooks/use-mounted'
import { cn } from '@/lib/utils'

export function ThemeToggle() {
  const { theme, setTheme, resolvedTheme } = useTheme()
  const mounted = useMounted()

  if (!mounted) {
    return (
      <Button variant="ghost" size="icon-sm" aria-label="Toggle theme" disabled>
        <span className="size-4" />
      </Button>
    )
  }

  // Cycle: system -> light -> dark -> system
  function cycleTheme() {
    if (theme === 'system') {
      setTheme('light')
    } else if (theme === 'light') {
      setTheme('dark')
    } else {
      setTheme('system')
    }
  }

  const currentTheme = theme || 'system'
  const isDark = resolvedTheme === 'dark'

  const title =
    currentTheme === 'system'
      ? `Theme: System (${isDark ? 'Dark' : 'Light'}) - Click for Light`
      : currentTheme === 'light'
        ? 'Theme: Light - Click for Dark'
        : 'Theme: Dark - Click for System'

  return (
    <Button
      variant="ghost"
      size="icon-sm"
      onClick={cycleTheme}
      title={title}
      aria-label={title}
    >
      {currentTheme === 'system' ? (
        <MonitorIcon className="size-4" />
      ) : currentTheme === 'light' ? (
        <SunIcon className="size-4" />
      ) : (
        <MoonIcon className="size-4" />
      )}
    </Button>
  )
}

export function ThemeSegmentedToggle() {
  const { theme, setTheme } = useTheme()
  const mounted = useMounted()

  if (!mounted) return null

  const current = theme || 'system'

  return (
    <div className="flex items-center justify-between gap-1 rounded-lg border bg-muted/40 p-1 text-xs">
      <button
        type="button"
        onClick={() => setTheme('system')}
        className={cn(
          'flex flex-1 items-center justify-center gap-1.5 rounded-md py-1.5 font-medium transition-all',
          current === 'system'
            ? 'bg-background text-foreground shadow-xs font-semibold'
            : 'text-muted-foreground hover:text-foreground',
        )}
      >
        <MonitorIcon className="size-3.5" />
        <span>System</span>
      </button>
      <button
        type="button"
        onClick={() => setTheme('light')}
        className={cn(
          'flex flex-1 items-center justify-center gap-1.5 rounded-md py-1.5 font-medium transition-all',
          current === 'light'
            ? 'bg-background text-foreground shadow-xs font-semibold'
            : 'text-muted-foreground hover:text-foreground',
        )}
      >
        <SunIcon className="size-3.5" />
        <span>Light</span>
      </button>
      <button
        type="button"
        onClick={() => setTheme('dark')}
        className={cn(
          'flex flex-1 items-center justify-center gap-1.5 rounded-md py-1.5 font-medium transition-all',
          current === 'dark'
            ? 'bg-background text-foreground shadow-xs font-semibold'
            : 'text-muted-foreground hover:text-foreground',
        )}
      >
        <MoonIcon className="size-3.5" />
        <span>Dark</span>
      </button>
    </div>
  )
}


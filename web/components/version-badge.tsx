import Link from 'next/link'
import { APP_VERSION } from '@/lib/version'
import { cn } from '@/lib/utils'

interface VersionBadgeProps {
  className?: string
  href?: string
  onClick?: () => void
}

export function VersionBadge({ className, href, onClick }: VersionBadgeProps) {
  const classes = cn(
    'inline-flex items-center rounded-md border border-border/70 bg-muted/60 px-1.5 py-0.5 font-mono text-[10px] font-medium text-muted-foreground select-none leading-none tracking-tight transition-colors',
    href && 'hover:bg-muted hover:border-foreground/30 hover:text-foreground cursor-pointer',
    className
  )

  if (href) {
    return (
      <Link
        href={href}
        onClick={onClick}
        className={classes}
        title={`Version ${APP_VERSION} - View About`}
        aria-label={`Version ${APP_VERSION}`}
      >
        v{APP_VERSION}
      </Link>
    )
  }

  return (
    <span
      className={classes}
      title={`Version ${APP_VERSION}`}
      aria-label={`Version ${APP_VERSION}`}
    >
      v{APP_VERSION}
    </span>
  )
}

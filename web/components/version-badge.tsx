import { APP_VERSION } from '@/lib/version'
import { cn } from '@/lib/utils'

interface VersionBadgeProps {
  className?: string
}

export function VersionBadge({ className }: VersionBadgeProps) {
  return (
    <span
      className={cn(
        'inline-flex items-center rounded-md border border-border/70 bg-muted/60 px-1.5 py-0.5 font-mono text-[10px] font-medium text-muted-foreground select-none leading-none tracking-tight',
        className
      )}
      title={`Version ${APP_VERSION}`}
      aria-label={`Version ${APP_VERSION}`}
    >
      v{APP_VERSION}
    </span>
  )
}

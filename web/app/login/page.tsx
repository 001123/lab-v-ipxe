'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import {
  ArrowRightIcon,
  EyeIcon,
  EyeOffIcon,
  KeyRoundIcon,
  Loader2Icon,
  LockIcon,
  LogInIcon,
  NetworkIcon,
} from 'lucide-react'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { ThemeToggle } from '@/components/theme-toggle'
import { VersionBadge } from '@/components/version-badge'
import { useAuth } from '@/hooks/use-auth'
import { apiErrorMessage } from '@/lib/api'

function ZtpIllustration({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 520 350"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={className}
      aria-label="iPXE Zero-Touch Provisioning Diagram"
    >
      <style>{`
        @keyframes flowDash {
          to { stroke-dashoffset: -20; }
        }
        @keyframes breatheGlow {
          0%, 100% { opacity: 0.05; }
          50% { opacity: 0.14; }
        }
        @keyframes pulseDot {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.25; }
        }
        .anim-flow {
          animation: flowDash 1.4s linear infinite;
        }
        .anim-glow {
          animation: breatheGlow 4s ease-in-out infinite;
        }
        .anim-pulse-fast {
          animation: pulseDot 1.2s ease-in-out infinite;
        }
        .anim-pulse-slow {
          animation: pulseDot 2s ease-in-out infinite;
        }
      `}</style>

      <defs>
        {/* Soft Drop Shadow for Cards */}
        <filter id="cardShadow" x="-20%" y="-20%" width="150%" height="150%">
          <feDropShadow dx="0" dy="2" stdDeviation="4" floodOpacity="0.08" />
        </filter>
        <radialGradient id="systemGlow" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stopColor="currentColor" stopOpacity="0.15" />
          <stop offset="100%" stopColor="currentColor" stopOpacity="0" />
        </radialGradient>
      </defs>

      {/* Ambient background breathing glow (pure opacity, zero layout shift) */}
      <circle cx="260" cy="175" r="160" fill="url(#systemGlow)" className="text-primary anim-glow" />

      {/* Subtle Circuit / Grid Lines */}
      <g className="stroke-border" strokeWidth="1" strokeDasharray="3 3" opacity="0.6">
        <line x1="20" y1="175" x2="205" y2="175" />
        <line x1="260" y1="20" x2="260" y2="330" />
      </g>

      {/* Flow Connection Animated Bézier Curves */}
      {/* Route 1: To Target 1 (Sanboot / Ready) */}
      <path
        d="M 205 150 C 275 150, 275 85, 350 85"
        className="stroke-emerald-500/70 anim-flow"
        strokeWidth="2"
        strokeDasharray="6 4"
        fill="none"
      />
      {/* Route 2: To Target 2 (Installing / Cloud-init) */}
      <path
        d="M 205 175 C 275 175, 275 175, 350 175"
        className="stroke-sky-500/70 anim-flow"
        strokeWidth="2"
        strokeDasharray="6 4"
        fill="none"
      />
      {/* Route 3: To Target 3 (Pending / MAC Discovery) */}
      <path
        d="M 205 200 C 275 200, 275 265, 350 265"
        className="stroke-amber-500/70 anim-flow"
        strokeWidth="2"
        strokeDasharray="6 4"
        fill="none"
      />

      {/* Traveling Data Packets along network paths */}
      {/* Packet 1: Emerald on Route 1 */}
      <g>
        <animateMotion
          path="M 205 150 C 275 150, 275 85, 350 85"
          dur="2.4s"
          repeatCount="indefinite"
        />
        <circle r="4" className="fill-emerald-400" />
        <circle r="1.8" fill="#ffffff" />
      </g>

      {/* Packet 2: Sky Blue on Route 2 */}
      <g>
        <animateMotion
          path="M 205 175 C 275 175, 275 175, 350 175"
          dur="2s"
          begin="-0.7s"
          repeatCount="indefinite"
        />
        <circle r="4" className="fill-sky-400" />
        <circle r="1.8" fill="#ffffff" />
      </g>

      {/* Packet 3: Amber on Route 3 */}
      <g>
        <animateMotion
          path="M 205 200 C 275 200, 275 265, 350 265"
          dur="2.8s"
          begin="-1.3s"
          repeatCount="indefinite"
        />
        <circle r="4" className="fill-amber-400" />
        <circle r="1.8" fill="#ffffff" />
      </g>

      {/* Stream Label Badges on Connection Lines */}
      <g transform="translate(242, 108)">
        <rect
          x="0"
          y="0"
          width="70"
          height="18"
          rx="9"
          className="fill-card stroke-border"
          strokeWidth="1"
        />
        <text
          x="35"
          y="12"
          className="fill-emerald-600 dark:fill-emerald-400 font-mono text-[9px] font-semibold"
          textAnchor="middle"
        >
          boot.ipxe
        </text>
      </g>
      <g transform="translate(237, 166)">
        <rect
          x="0"
          y="0"
          width="80"
          height="18"
          rx="9"
          className="fill-card stroke-border"
          strokeWidth="1"
        />
        <text
          x="40"
          y="12"
          className="fill-sky-600 dark:fill-sky-400 font-mono text-[9px] font-semibold"
          textAnchor="middle"
        >
          cloud-init
        </text>
      </g>
      <g transform="translate(244, 224)">
        <rect
          x="0"
          y="0"
          width="66"
          height="18"
          rx="9"
          className="fill-card stroke-border"
          strokeWidth="1"
        />
        <text
          x="33"
          y="12"
          className="fill-amber-600 dark:fill-amber-400 font-mono text-[9px] font-semibold"
          textAnchor="middle"
        >
          opt:175
        </text>
      </g>

      {/* Central Hub: iPXE ZTP Controller */}
      <g transform="translate(30, 105)" filter="url(#cardShadow)">
        {/* Hub Body */}
        <rect
          x="0"
          y="0"
          width="175"
          height="140"
          rx="16"
          className="fill-card stroke-border"
          strokeWidth="1.5"
        />

        {/* Server Top Header Bar */}
        <rect
          x="0"
          y="0"
          width="175"
          height="34"
          rx="16"
          className="fill-muted/70"
        />
        <circle cx="18" cy="17" r="3.5" className="fill-primary anim-pulse-slow" />
        <circle cx="28" cy="17" r="3.5" className="fill-emerald-500 anim-pulse-fast" />
        <text
          x="40"
          y="21"
          className="fill-foreground font-sans text-[11px] font-bold"
        >
          iPXE ZTP
        </text>
        <rect
          x="121"
          y="8"
          width="42"
          height="18"
          rx="4"
          className="fill-primary/10 stroke-primary/20"
          strokeWidth="1"
        />
        <text
          x="142"
          y="20"
          className="fill-primary font-mono text-[9px] font-semibold"
          textAnchor="middle"
        >
          :4793
        </text>

        {/* Server Blade Rack Slots */}
        {/* Blade 1 */}
        <rect
          x="12" y="44" width="151" height="24" rx="6"
          className="fill-muted/40 stroke-border/60"
          strokeWidth="1"
        />
        <circle cx="22" cy="56" r="3" className="fill-emerald-500 anim-pulse-slow" />
        <text x="32" y="59" className="fill-muted-foreground font-mono text-[10px]">
          iPXE HTTP
        </text>
        <rect x="115" y="49" width="40" height="14" rx="3" className="fill-emerald-500/15" />
        <text
          x="135"
          y="60"
          className="fill-emerald-600 dark:fill-emerald-400 font-mono text-[8px] font-semibold"
          textAnchor="middle"
        >
          ACTIVE
        </text>

        {/* Blade 2 */}
        <rect
          x="12" y="74" width="151" height="24" rx="6"
          className="fill-muted/40 stroke-border/60"
          strokeWidth="1"
        />
        <circle cx="22" cy="86" r="3" className="fill-sky-500 anim-pulse-fast" />
        <text x="32" y="89" className="fill-muted-foreground font-mono text-[10px]">
          NFS / Kernel
        </text>
        <rect x="115" y="79" width="40" height="14" rx="3" className="fill-sky-500/15" />
        <text
          x="135"
          y="90"
          className="fill-sky-600 dark:fill-sky-400 font-mono text-[8px] font-semibold"
          textAnchor="middle"
        >
          STREAM
        </text>

        {/* Blade 3 */}
        <rect
          x="12" y="104" width="151" height="24" rx="6"
          className="fill-muted/40 stroke-border/60"
          strokeWidth="1"
        />
        <circle cx="22" cy="116" r="3" className="fill-primary anim-pulse-slow" />
        <text x="32" y="119" className="fill-muted-foreground font-mono text-[10px]">
          SQLite DB
        </text>
        <rect x="115" y="109" width="40" height="14" rx="3" className="fill-primary/10" />
        <text
          x="135"
          y="120"
          className="fill-primary font-mono text-[8px] font-semibold"
          textAnchor="middle"
        >
          SYNCED
        </text>
      </g>

      {/* Target Nodes (Cluster Machines) */}
      {/* Node 1: Ready / Sanboot */}
      <g transform="translate(350, 55)" filter="url(#cardShadow)">
        <rect
          x="0" y="0" width="140" height="60" rx="12"
          className="fill-card stroke-border"
          strokeWidth="1.2"
        />
        <circle cx="18" cy="20" r="4" className="fill-emerald-500 anim-pulse-slow" />
        <text x="28" y="24" className="fill-foreground font-sans text-[11px] font-semibold">
          node-01.local
        </text>
        <text
          x="18"
          y="44"
          className="fill-emerald-600 dark:fill-emerald-400 font-mono text-[10px] font-medium"
        >
          ● Ready (Sanboot)
        </text>
      </g>

      {/* Node 2: Installing / Autoinstall */}
      <g transform="translate(350, 145)" filter="url(#cardShadow)">
        <rect
          x="0" y="0" width="140" height="60" rx="12"
          className="fill-card stroke-border"
          strokeWidth="1.2"
        />
        <circle cx="18" cy="20" r="4" className="fill-sky-500 anim-pulse-fast" />
        <text x="28" y="24" className="fill-foreground font-sans text-[11px] font-semibold">
          node-02.local
        </text>
        <text
          x="18"
          y="44"
          className="fill-sky-600 dark:fill-sky-400 font-mono text-[10px] font-medium"
        >
          ● Installing OS...
        </text>
      </g>

      {/* Node 3: Pending Discovery */}
      <g transform="translate(350, 235)" filter="url(#cardShadow)">
        <rect
          x="0" y="0" width="140" height="60" rx="12"
          className="fill-card stroke-border"
          strokeWidth="1.2"
        />
        <circle cx="18" cy="20" r="4" className="fill-amber-500 anim-pulse-slow" />
        <text x="28" y="24" className="fill-foreground font-sans text-[11px] font-semibold">
          52:54:00:99:00:01
        </text>
        <text
          x="18"
          y="44"
          className="fill-amber-600 dark:fill-amber-400 font-mono text-[10px] font-medium"
        >
          ● Pending Review
        </text>
      </g>
    </svg>
  )
}

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
      toast.warning('Please enter both email and password')
      return
    }
    setLoading(true)
    try {
      await login(email, password)
      toast.success('Signed in successfully')
      router.push('/machines')
    } catch (err) {
      toast.error(apiErrorMessage(err))
    } finally {
      setLoading(false)
    }
  }

  function handleQuickFill() {
    setEmail('admin@ipxe.local')
    setPassword('admin@pwd')
    toast.info('Default credentials applied (admin@ipxe.local / admin@pwd)')
  }

  return (
    <div className="relative min-h-dvh flex bg-background">
      {/* ========================================================================= */}
      {/* LEFT SECTION: System-Themed Showcase (Desktop Only, hidden on Mobile)     */}
      {/* ========================================================================= */}
      <div className="hidden lg:flex lg:flex-col lg:justify-between overflow-hidden bg-muted/40 dark:bg-muted/15 border-r border-border p-8 lg:p-12 xl:p-16 lg:w-[50%] xl:w-[54%]">
        {/* Top Branding (Unified with AppShell) */}
        <div className="relative z-10 flex items-center gap-2.5">
          <div className="flex size-8 items-center justify-center rounded-lg bg-primary/10 text-primary">
            <NetworkIcon className="size-4.5" />
          </div>
          <span className="font-bold tracking-tight text-lg text-foreground">
            iPXE ZTP
          </span>
          <VersionBadge />
        </div>

        {/* Center: Concise Hero + Animated System-Themed SVG Illustration */}
        <div className="relative z-10 my-auto flex flex-col items-center text-center space-y-6">
          <div className="space-y-2 max-w-md">
            <h1 className="text-2xl sm:text-3xl font-extrabold tracking-tight text-foreground">
              Zero-Touch Server Provisioning
            </h1>
            <p className="text-sm text-muted-foreground leading-relaxed font-normal">
              Automated bare-metal and hypervisor VM deployment over the local network.
            </p>
          </div>

          {/* High-Tech Animated Architecture SVG */}
          <div className="w-full max-w-lg mx-auto py-2">
            <ZtpIllustration className="w-full h-auto" />
          </div>
        </div>

        {/* Empty placeholder to keep vertical centering balanced with top header */}
        <div className="h-8" aria-hidden="true" />
      </div>

      {/* ========================================================================= */}
      {/* RIGHT SECTION: Minimal, Streamlined Authentication Panel                   */}
      {/* ========================================================================= */}
      <div className="relative flex flex-1 flex-col justify-between bg-background p-6 sm:p-10 lg:p-12">
        {/* Top Header: Brand on Mobile, Theme Switcher on Right */}
        <div className="flex items-center justify-between lg:justify-end w-full">
          <div className="flex items-center gap-2 lg:hidden">
            <div className="flex size-7 items-center justify-center rounded-md bg-primary/10 text-primary">
              <NetworkIcon className="size-4" />
            </div>
            <span className="font-semibold text-sm text-foreground">iPXE ZTP</span>
            <VersionBadge />
          </div>
          <ThemeToggle />
        </div>

        {/* Centered Login Card */}
        <div className="my-auto w-full max-w-[380px] mx-auto py-6">
          <Card className="border border-border shadow-md bg-card">
            <CardContent className="p-6 sm:p-8 space-y-6">
              {/* Header */}
              <div className="space-y-2 text-left">
                <div className="flex size-9 items-center justify-center rounded-lg bg-primary/10 text-primary">
                  <LockIcon className="size-4" />
                </div>
                <h2 className="text-xl sm:text-2xl font-bold tracking-tight text-foreground">
                  Sign in to Console
                </h2>
              </div>

              {/* Login Form */}
              <form onSubmit={onSubmit} className="space-y-4">
                <div className="space-y-1.5">
                  <Label htmlFor="email" className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                    Email Address
                  </Label>
                  <Input
                    id="email"
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="admin@ipxe.local"
                    autoComplete="username"
                    required
                    className="h-10 text-sm focus-visible:ring-primary/40"
                  />
                </div>

                <div className="space-y-1.5">
                  <Label htmlFor="password" className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                    Password
                  </Label>
                  <div className="relative">
                    <Input
                      id="password"
                      type={showPassword ? 'text' : 'password'}
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      placeholder="••••••••••••"
                      autoComplete="current-password"
                      required
                      className="h-10 pr-10 text-sm focus-visible:ring-primary/40 font-mono"
                    />
                    <Button
                      type="button"
                      variant="ghost"
                      size="icon-sm"
                      className="absolute top-1.5 right-1.5 size-7 text-muted-foreground hover:text-foreground"
                      onClick={() => setShowPassword((v) => !v)}
                      aria-label={showPassword ? 'Hide password' : 'Show password'}
                    >
                      {showPassword ? (
                        <EyeOffIcon className="size-4" />
                      ) : (
                        <EyeIcon className="size-4" />
                      )}
                    </Button>
                  </div>
                </div>

                {/* Quick Dev/Lab Credentials Helper */}
                <div className="rounded-lg border border-border/60 bg-muted/40 p-3 text-xs flex items-center justify-between gap-3">
                  <div className="flex items-center gap-2 text-muted-foreground min-w-0">
                    <KeyRoundIcon className="size-3.5 shrink-0 text-primary/70" />
                    <span className="truncate">
                      Default: <span className="font-mono text-foreground font-medium">admin@ipxe.local</span>
                    </span>
                  </div>
                  <Button
                    type="button"
                    variant="outline"
                    size="xs"
                    onClick={handleQuickFill}
                    className="shrink-0 text-[11px] font-medium hover:bg-background"
                  >
                    Quick Fill
                  </Button>
                </div>

                <Button
                  type="submit"
                  disabled={loading}
                  size="lg"
                  className="w-full h-10 text-sm font-semibold shadow-xs transition-all active:scale-[0.99]"
                >
                  {loading ? (
                    <>
                      <Loader2Icon data-icon="inline-start" className="animate-spin size-4" />
                      <span>Authenticating...</span>
                    </>
                  ) : (
                    <>
                      <LogInIcon data-icon="inline-start" className="size-4" />
                      <span>Sign In to Dashboard</span>
                      <ArrowRightIcon className="ml-auto size-4 opacity-70" />
                    </>
                  )}
                </Button>
              </form>
            </CardContent>
          </Card>
        </div>

        {/* Empty placeholder to keep vertical centering balanced with top header */}
        <div className="h-6" aria-hidden="true" />
      </div>
    </div>
  )
}

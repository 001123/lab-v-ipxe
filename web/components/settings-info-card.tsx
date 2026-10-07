'use client'

import { useState } from 'react'
import { CheckCircle2, Cpu, Globe, Layout, Layers, RefreshCw, Server } from 'lucide-react'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import { useSettings } from '@/hooks/use-settings'

function formatBytes(bytes: number): string {
  if (!bytes || bytes <= 0) return '0 MB'
  const mb = bytes / (1024 * 1024)
  if (mb < 1024) {
    return `${mb.toFixed(1)} MB`
  }
  return `${(mb / 1024).toFixed(2)} GB`
}

function formatUptime(seconds: number): string {
  if (!seconds || seconds <= 0) return '< 1m'
  const d = Math.floor(seconds / 86400)
  const h = Math.floor((seconds % 86400) / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  const s = Math.floor(seconds % 60)

  const parts = []
  if (d > 0) parts.push(`${d}d`)
  if (h > 0) parts.push(`${h}h`)
  if (m > 0) parts.push(`${m}m`)
  if (parts.length === 0 || s > 0) parts.push(`${s}s`)
  return parts.join(' ')
}

export function SettingsInfoCard() {
  const { settings, mutate } = useSettings()
  const [refreshing, setRefreshing] = useState(false)

  const sys = settings?.system
  const isUnified = sys?.unified_process ?? false
  const beMem = sys?.backend.memory_bytes ?? 0
  const feMem = sys?.frontend.memory_bytes ?? 0
  const totalMem = isUnified ? beMem : beMem + feMem

  const bePort = sys?.backend.port || sys?.port || 4793
  const fePort = sys?.frontend.port || 4794

  const handleRefresh = async () => {
    setRefreshing(true)
    try {
      await mutate()
    } finally {
      setTimeout(() => setRefreshing(false), 300)
    }
  }

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between border-b bg-muted/15 px-6 py-4">
        <div className="space-y-1">
          <div className="flex items-center gap-2.5">
            <CardTitle className="text-lg font-semibold tracking-tight">Info</CardTitle>
            {sys ? (
              isUnified ? (
                <Badge variant="outline" className="border-emerald-500/40 bg-emerald-500/10 text-emerald-600 text-[11px] font-medium dark:text-emerald-400">
                  <CheckCircle2 className="mr-1 h-3 w-3" />
                  Production (Unified single-port :{bePort})
                </Badge>
              ) : (
                <Badge variant="outline" className="border-blue-500/40 bg-blue-500/10 text-blue-600 text-[11px] font-medium dark:text-blue-400">
                  <Globe className="mr-1 h-3 w-3" />
                  Development (:{bePort} + :{fePort})
                </Badge>
              )
            ) : null}
          </div>
          <CardDescription>
            {isUnified
              ? 'Single-process production runtime serving both API and embedded web UI on one port.'
              : 'Process memory usage and runtime diagnostics for backend and frontend services.'}
          </CardDescription>
        </div>
        <Button
          variant="outline"
          size="sm"
          onClick={handleRefresh}
          disabled={refreshing}
          className="h-8 gap-1.5 text-xs font-medium"
        >
          <RefreshCw className={`h-3.5 w-3.5 ${refreshing ? 'animate-spin' : ''}`} />
          Refresh
        </Button>
      </CardHeader>
      <CardContent className="space-y-6 p-6">
        {/* Metric Summary Cards */}
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
          {/* Backend Mem */}
          <div className="rounded-xl border bg-card p-4 shadow-xs">
            <div className="flex items-center justify-between">
              <span className="text-xs font-medium text-muted-foreground">
                {isUnified ? 'App Process Memory' : 'Backend Memory'}
              </span>
              <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-emerald-500/10 text-emerald-600 dark:text-emerald-400">
                <Cpu className="h-4 w-4" />
              </div>
            </div>
            <div className="mt-2 text-2xl font-bold tracking-tight">
              {sys ? formatBytes(beMem) : '—'}
            </div>
            <div className="mt-1 flex items-center gap-1.5 text-xs text-muted-foreground">
              <Badge variant="outline" className="px-1.5 py-0 text-[10px] font-mono">
                PID {sys?.backend.pid || '—'}
              </Badge>
              <span className="truncate">Port :{bePort}</span>
            </div>
          </div>

          {/* Frontend Mem */}
          <div className="rounded-xl border bg-card p-4 shadow-xs">
            <div className="flex items-center justify-between">
              <span className="text-xs font-medium text-muted-foreground">Frontend Memory</span>
              <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-blue-500/10 text-blue-600 dark:text-blue-400">
                <Layout className="h-4 w-4" />
              </div>
            </div>
            <div className="mt-2 text-2xl font-bold tracking-tight">
              {sys ? (isUnified ? 'Embedded' : feMem > 0 ? formatBytes(feMem) : '0 MB') : '—'}
            </div>
            <div className="mt-1 flex items-center gap-1.5 text-xs text-muted-foreground">
              {isUnified ? (
                <>
                  <Badge variant="outline" className="px-1.5 py-0 text-[10px] font-medium text-emerald-600 dark:text-emerald-400">
                    Single binary
                  </Badge>
                  <span className="truncate">Shared port :{bePort}</span>
                </>
              ) : (
                <>
                  {sys?.frontend.pid ? (
                    <Badge variant="outline" className="px-1.5 py-0 text-[10px] font-mono">
                      PID {sys.frontend.pid}
                    </Badge>
                  ) : null}
                  <span className="truncate">Port :{fePort}</span>
                </>
              )}
            </div>
          </div>

          {/* Combined Total */}
          <div className="rounded-xl border bg-card p-4 shadow-xs">
            <div className="flex items-center justify-between">
              <span className="text-xs font-medium text-muted-foreground">Total Resident RSS</span>
              <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary/10 text-primary">
                <Layers className="h-4 w-4" />
              </div>
            </div>
            <div className="mt-2 text-2xl font-bold tracking-tight">
              {sys ? formatBytes(totalMem) : '—'}
            </div>
            <div className="mt-1 flex items-center gap-1.5 text-xs text-muted-foreground">
              <span>Host:</span>
              <Badge variant="secondary" className="px-1.5 py-0 text-[10px] font-medium capitalize">
                {sys?.os_type || '—'}
              </Badge>
              <span>• {sys ? formatUptime(sys.uptime_sec) : '—'}</span>
            </div>
          </div>
        </div>

        {/* Detailed Process Breakdown */}
        <dl className="divide-y rounded-lg border text-sm">
          <div className="grid grid-cols-[200px_1fr] items-center gap-2 px-4 py-2.5">
            <dt className="text-muted-foreground font-medium">
              {isUnified ? 'Unified app process' : 'Backend service'}
            </dt>
            <dd className="flex items-center justify-between gap-2">
              <div className="flex items-center gap-2">
                <span className="font-medium text-foreground">
                  {sys?.backend.name || (isUnified ? 'Backend & App Server' : 'Backend (V / veb)')}
                </span>
                <span className="text-xs text-muted-foreground font-mono">PID {sys?.backend.pid}</span>
                <Badge variant="outline" className="text-[11px] text-muted-foreground">
                  {sys?.backend.mode}
                </Badge>
              </div>
              <span className="font-mono font-medium text-foreground">{sys ? formatBytes(beMem) : '—'}</span>
            </dd>
          </div>

          <div className="grid grid-cols-[200px_1fr] items-center gap-2 px-4 py-2.5">
            <dt className="text-muted-foreground font-medium">Frontend service</dt>
            <dd className="flex items-center justify-between gap-2">
              <div className="flex items-center gap-2">
                <span className="font-medium text-foreground">
                  {isUnified ? 'Frontend (Embedded SPA assets)' : sys?.frontend.name || 'Frontend (Next.js)'}
                </span>
                {isUnified ? (
                  <Badge variant="outline" className="text-[11px] text-emerald-600 dark:text-emerald-400">
                    Embedded in binary (port :{bePort})
                  </Badge>
                ) : (
                  <>
                    {sys?.frontend.pid ? (
                      <span className="text-xs text-muted-foreground font-mono">PID {sys.frontend.pid}</span>
                    ) : null}
                    <Badge variant="outline" className="text-[11px] text-muted-foreground">
                      {sys?.frontend.mode || 'Next.js'}
                    </Badge>
                  </>
                )}
              </div>
              <span className="font-mono font-medium text-foreground">
                {sys ? (isUnified ? 'Embedded (included in App RAM)' : feMem > 0 ? formatBytes(feMem) : '0 B') : '—'}
              </span>
            </dd>
          </div>

          <div className="grid grid-cols-[200px_1fr] items-center gap-2 px-4 py-2.5 bg-muted/10">
            <dt className="text-foreground font-medium">Total resident memory (RSS)</dt>
            <dd className="flex items-center justify-between gap-2">
              <span className="text-xs text-muted-foreground">
                {isUnified
                  ? 'Total memory consumed by the unified single binary process'
                  : 'Combined resident memory of active backend and frontend processes'}
              </span>
              <span className="font-mono font-semibold text-foreground">{sys ? formatBytes(totalMem) : '—'}</span>
            </dd>
          </div>

          <div className="grid grid-cols-[200px_1fr] items-center gap-2 px-4 py-2.5">
            <dt className="text-muted-foreground font-medium">Network runtime</dt>
            <dd className="text-foreground font-medium flex items-center gap-2">
              {isUnified ? (
                <span>Single HTTP port: <code className="font-mono text-xs bg-muted px-1.5 py-0.5 rounded">:{bePort}</code> (API, iPXE & UI)</span>
              ) : (
                <span>Dual ports: Backend on <code className="font-mono text-xs bg-muted px-1.5 py-0.5 rounded">:{bePort}</code>, Web dev on <code className="font-mono text-xs bg-muted px-1.5 py-0.5 rounded">:{fePort}</code></span>
              )}
            </dd>
          </div>

          <div className="grid grid-cols-[200px_1fr] items-center gap-2 px-4 py-2.5">
            <dt className="text-muted-foreground font-medium">Operating system</dt>
            <dd className="capitalize text-foreground font-medium">{sys?.os_type || '—'}</dd>
          </div>

          <div className="grid grid-cols-[200px_1fr] items-center gap-2 px-4 py-2.5">
            <dt className="text-muted-foreground font-medium">Server uptime</dt>
            <dd className="font-mono text-foreground">{sys ? formatUptime(sys.uptime_sec) : '—'}</dd>
          </div>
        </dl>
      </CardContent>
    </Card>
  )
}

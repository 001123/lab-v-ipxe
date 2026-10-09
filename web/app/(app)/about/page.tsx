'use client'

import { useState } from 'react'
import {
  CheckCircle2,
  Cpu,
  ExternalLink,
  GitBranch,
  HardDrive,
  History,
  Info,
  Layers,
  Network,
  RefreshCw,
  Server,
  ShieldCheck,
  Sparkles,
  Terminal,
} from 'lucide-react'
import { Badge } from '@/components/ui/badge'
import { Button, buttonVariants } from '@/components/ui/button'
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { APP_VERSION } from '@/lib/version'
import { cn } from '@/lib/utils'

const GITHUB_REPO_URL = 'https://github.com/001123/lab-v-ipxe'

function GithubIcon(props: React.ComponentProps<'svg'>) {
  return (
    <svg
      role="img"
      viewBox="0 0 24 24"
      fill="currentColor"
      xmlns="http://www.w3.org/2000/svg"
      {...props}
    >
      <path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12" />
    </svg>
  )
}

export default function AboutPage() {
  const [activeTab, setActiveTab] = useState('overview')

  return (
    <div className="mx-auto flex max-w-[1200px] flex-col gap-4 sm:gap-6">
      {/* Top Header Banner */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between border-b pb-4 sm:pb-5">
        <div className="space-y-1">
          <div className="flex flex-wrap items-center gap-2 sm:gap-3">
            <h1 className="text-xl font-bold tracking-tight text-foreground sm:text-2xl lg:text-3xl">
              About iPXE ZTP
            </h1>
            <Badge variant="outline" className="border-primary/30 bg-primary/10 text-primary font-mono text-[11px] sm:text-xs">
              v{APP_VERSION}
            </Badge>
            <Badge variant="secondary" className="font-mono text-[10px] sm:hidden">
              MIT License
            </Badge>
          </div>
          <p className="text-xs sm:text-sm text-muted-foreground max-w-2xl leading-relaxed">
            Zero Touch Provisioning server for automated network installation of bare-metal machines,
            packaged as an ultra-fast, single self-contained binary.
          </p>
        </div>

        {/* Action Buttons: 2-column grid on mobile for effortless tapping, inline on desktop */}
        <div className="grid grid-cols-2 gap-2 sm:flex sm:items-center sm:w-auto w-full pt-1 sm:pt-0">
          <a
            href={GITHUB_REPO_URL}
            target="_blank"
            rel="noopener noreferrer"
            className={cn(
              buttonVariants({ variant: 'outline', size: 'sm' }),
              'h-9 sm:h-8 gap-1.5 text-xs font-medium justify-center'
            )}
          >
            <GithubIcon className="size-3.5" />
            <span>GitHub</span>
            <ExternalLink className="size-3 opacity-60" />
          </a>
          <a
            href={`${GITHUB_REPO_URL}#readme`}
            target="_blank"
            rel="noopener noreferrer"
            className={cn(
              buttonVariants({ variant: 'outline', size: 'sm' }),
              'h-9 sm:h-8 gap-1.5 text-xs font-medium justify-center'
            )}
          >
            <Terminal className="size-3.5" />
            <span>Documentation</span>
            <ExternalLink className="size-3 opacity-60" />
          </a>
        </div>
      </div>

      {/* Main Tabbed Interface */}
      <Tabs value={activeTab} onValueChange={setActiveTab} className="w-full space-y-4 sm:space-y-6">
        {/* Mobile-optimized Tab Bar: horizontally scrollable on mobile without awkward row wrapping */}
        <div className="-mx-4 px-4 sm:mx-0 sm:px-0 overflow-x-auto scrollbar-none">
          <TabsList className="inline-flex h-9.5 w-full sm:w-auto min-w-full sm:min-w-0 p-1 bg-muted/60 gap-1 justify-between sm:justify-start">
            <TabsTrigger
              value="overview"
              className="flex-1 sm:flex-initial gap-1.5 px-2.5 sm:px-3 py-1.5 text-xs sm:text-sm font-medium whitespace-nowrap"
            >
              <Info className="size-3.5 sm:size-4 shrink-0" />
              <span>Overview</span>
            </TabsTrigger>
            <TabsTrigger
              value="tech"
              className="flex-1 sm:flex-initial gap-1.5 px-2.5 sm:px-3 py-1.5 text-xs sm:text-sm font-medium whitespace-nowrap"
            >
              <Layers className="size-3.5 sm:size-4 shrink-0" />
              <span>Tech Stack</span>
            </TabsTrigger>
            <TabsTrigger
              value="changelog"
              className="flex-1 sm:flex-initial gap-1.5 px-2.5 sm:px-3 py-1.5 text-xs sm:text-sm font-medium whitespace-nowrap"
            >
              <History className="size-3.5 sm:size-4 shrink-0" />
              <span>Changelog</span>
            </TabsTrigger>
            <TabsTrigger
              value="updates"
              className="flex-1 sm:flex-initial gap-1.5 px-2.5 sm:px-3 py-1.5 text-xs sm:text-sm font-medium whitespace-nowrap"
            >
              <RefreshCw className="size-3.5 sm:size-4 shrink-0" />
              <span>Updates</span>
            </TabsTrigger>
          </TabsList>
        </div>

        {/* ===================== TAB 1: OVERVIEW ===================== */}
        <TabsContent value="overview" className="space-y-4 sm:space-y-6">
          {/* Hero Card */}
          <Card>
            <CardHeader className="border-b bg-muted/15 px-4 py-3.5 sm:px-6 sm:py-4">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2.5 sm:gap-3">
                  <div className="flex size-8 sm:size-9 items-center justify-center rounded-lg bg-primary/10 text-primary shrink-0">
                    <Network className="size-4 sm:size-5" />
                  </div>
                  <div>
                    <CardTitle className="text-sm sm:text-lg">Project Overview</CardTitle>
                    <CardDescription className="text-xs sm:text-sm line-clamp-1 sm:line-clamp-none">
                      Zero Touch Provisioning (ZTP) network infrastructure & machine orchestration
                    </CardDescription>
                  </div>
                </div>
                <Badge variant="secondary" className="font-mono text-xs hidden sm:inline-flex shrink-0">
                  MIT License
                </Badge>
              </div>
            </CardHeader>
            <CardContent className="space-y-3 sm:space-y-4 p-4 sm:p-6 text-xs sm:text-sm text-muted-foreground leading-relaxed">
              <p>
                <strong className="text-foreground font-semibold">iPXE ZTP</strong> is an automated bare-metal
                and virtual machine provisioning server engineered as a single, self-contained binary with zero
                external runtime dependencies. It combines an iPXE HTTP boot service, dynamic cloud-init
                autoinstall templating, SQLite-backed state tracking, and a reactive administration console.
              </p>
              <p>
                When an unknown machine boots via PXE/TFTP on your local network, it automatically checks in
                with the server. Administrators can approve pending machines with custom hostnames, static or DHCP
                IP configurations, and storage layouts. The server then orchestrates automated unattended
                operating system installations (Ubuntu 24.04.5 LTS / 26.04.1) over NFS rootfs.
              </p>
            </CardContent>
          </Card>

          {/* Key Capabilities */}
          <div className="grid grid-cols-1 gap-3 sm:gap-4 sm:grid-cols-2">
            <Card className="shadow-xs">
              <CardHeader className="p-4 pb-1.5 sm:p-6 sm:pb-2">
                <div className="flex items-center gap-2 sm:gap-2.5">
                  <div className="flex size-7 items-center justify-center rounded-md bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 shrink-0">
                    <Sparkles className="size-3.5 sm:size-4" />
                  </div>
                  <CardTitle className="text-xs sm:text-sm font-semibold">Zero-Touch Provisioning</CardTitle>
                </div>
              </CardHeader>
              <CardContent className="p-4 pt-1 sm:p-6 sm:pt-2 text-xs text-muted-foreground leading-normal">
                Discovers unknown MAC addresses immediately upon network boot, presents an approval drawer in the web UI,
                and generates tailored iPXE scripts and autoinstall user-data payloads.
              </CardContent>
            </Card>

            <Card className="shadow-xs">
              <CardHeader className="p-4 pb-1.5 sm:p-6 sm:pb-2">
                <div className="flex items-center gap-2 sm:gap-2.5">
                  <div className="flex size-7 items-center justify-center rounded-md bg-blue-500/10 text-blue-600 dark:text-blue-400 shrink-0">
                    <Cpu className="size-3.5 sm:size-4" />
                  </div>
                  <CardTitle className="text-xs sm:text-sm font-semibold">Single-Binary Architecture</CardTitle>
                </div>
              </CardHeader>
              <CardContent className="p-4 pt-1 sm:p-6 sm:pt-2 text-xs text-muted-foreground leading-normal">
                The entire solution—backend API, iPXE HTTP responder, and embedded Next.js 16 web application—is
                compiled into one single native binary for seamless deployment and low memory overhead.
              </CardContent>
            </Card>

            <Card className="shadow-xs">
              <CardHeader className="p-4 pb-1.5 sm:p-6 sm:pb-2">
                <div className="flex items-center gap-2 sm:gap-2.5">
                  <div className="flex size-7 items-center justify-center rounded-md bg-amber-500/10 text-amber-600 dark:text-amber-400 shrink-0">
                    <HardDrive className="size-3.5 sm:size-4" />
                  </div>
                  <CardTitle className="text-xs sm:text-sm font-semibold">Flexible Storage Layouts</CardTitle>
                </div>
              </CardHeader>
              <CardContent className="p-4 pt-1 sm:p-6 sm:pt-2 text-xs text-muted-foreground leading-normal">
                Configurable per-machine disk profiles including Direct Ext4 (default), ZFS root with automatic
                ARC tuning for low-memory hosts, and standard LVM partition layouts.
              </CardContent>
            </Card>

            <Card className="shadow-xs">
              <CardHeader className="p-4 pb-1.5 sm:p-6 sm:pb-2">
                <div className="flex items-center gap-2 sm:gap-2.5">
                  <div className="flex size-7 items-center justify-center rounded-md bg-primary/10 text-primary shrink-0">
                    <ShieldCheck className="size-3.5 sm:size-4" />
                  </div>
                  <CardTitle className="text-xs sm:text-sm font-semibold">Phone-Home Verification</CardTitle>
                </div>
              </CardHeader>
              <CardContent className="p-4 pt-1 sm:p-6 sm:pt-2 text-xs text-muted-foreground leading-normal">
                Automated post-install verification hooks prevent boot loops by seamlessly transitioning finished machines
                to local disk sanboot once cloud-init installation succeeds.
              </CardContent>
            </Card>
          </div>

          {/* Quick Links Card */}
          <Card>
            <CardHeader className="px-4 py-3 sm:px-6 sm:py-4 border-b bg-muted/15">
              <CardTitle className="text-xs sm:text-sm font-semibold">Project Links & Resources</CardTitle>
            </CardHeader>
            <CardContent className="p-4 sm:p-6">
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-2.5 sm:gap-3">
                <a
                  href={GITHUB_REPO_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center justify-between p-3 rounded-lg border bg-card hover:bg-muted/50 active:bg-muted/80 transition-colors text-xs font-medium min-h-[44px]"
                >
                  <span className="flex items-center gap-2">
                    <GithubIcon className="size-4 text-muted-foreground" />
                    Source Code
                  </span>
                  <ExternalLink className="size-3.5 text-muted-foreground" />
                </a>

                <a
                  href={`${GITHUB_REPO_URL}#readme`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center justify-between p-3 rounded-lg border bg-card hover:bg-muted/50 active:bg-muted/80 transition-colors text-xs font-medium min-h-[44px]"
                >
                  <span className="flex items-center gap-2">
                    <Terminal className="size-4 text-muted-foreground" />
                    Documentation
                  </span>
                  <ExternalLink className="size-3.5 text-muted-foreground" />
                </a>

                <a
                  href={`${GITHUB_REPO_URL}/releases`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center justify-between p-3 rounded-lg border bg-card hover:bg-muted/50 active:bg-muted/80 transition-colors text-xs font-medium min-h-[44px]"
                >
                  <span className="flex items-center gap-2">
                    <GitBranch className="size-4 text-muted-foreground" />
                    GitHub Releases
                  </span>
                  <ExternalLink className="size-3.5 text-muted-foreground" />
                </a>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* ===================== TAB 2: TECH STACK ===================== */}
        <TabsContent value="tech" className="space-y-4 sm:space-y-6">
          <Card>
            <CardHeader className="border-b bg-muted/15 px-4 py-3.5 sm:px-6 sm:py-4">
              <div className="flex items-center gap-2.5 sm:gap-3">
                <div className="flex size-8 sm:size-9 items-center justify-center rounded-lg bg-blue-500/10 text-blue-600 dark:text-blue-400 shrink-0">
                  <Layers className="size-4 sm:size-5" />
                </div>
                <div>
                  <CardTitle className="text-sm sm:text-lg">Architecture & Technologies</CardTitle>
                  <CardDescription className="text-xs sm:text-sm">
                    End-to-end overview of components powering the iPXE ZTP stack
                  </CardDescription>
                </div>
              </div>
            </CardHeader>
            <CardContent className="space-y-4 sm:space-y-6 p-4 sm:p-6">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3 sm:gap-4">
                {/* Backend Spec */}
                <div className="rounded-lg border p-3.5 sm:p-4 space-y-3 bg-muted/10">
                  <div className="flex items-center justify-between">
                    <span className="font-semibold text-xs sm:text-sm flex items-center gap-2 text-foreground">
                      <Server className="size-4 text-primary" />
                      Backend Core
                    </span>
                    <Badge variant="outline" className="text-[10px] sm:text-[11px] font-mono">
                      V 0.5.2
                    </Badge>
                  </div>
                  <ul className="space-y-2 text-xs text-muted-foreground">
                    <li className="flex flex-col xs:flex-row xs:items-center justify-between gap-0.5 xs:gap-2 py-0.5 border-b border-border/40">
                      <span>Language runtime:</span>
                      <span className="font-mono text-foreground font-medium">Vlang 0.5.2 (Native C)</span>
                    </li>
                    <li className="flex flex-col xs:flex-row xs:items-center justify-between gap-0.5 xs:gap-2 py-0.5 border-b border-border/40">
                      <span>HTTP & Routing engine:</span>
                      <span className="font-mono text-foreground font-medium">veb (bundled in vlib)</span>
                    </li>
                    <li className="flex flex-col xs:flex-row xs:items-center justify-between gap-0.5 xs:gap-2 py-0.5 border-b border-border/40">
                      <span>Persistence layer:</span>
                      <span className="font-mono text-foreground font-medium">SQLite 3 (WAL mode)</span>
                    </li>
                    <li className="flex flex-col xs:flex-row xs:items-center justify-between gap-0.5 xs:gap-2 py-0.5">
                      <span>Packaging:</span>
                      <span className="font-mono text-foreground font-medium">Single static binary</span>
                    </li>
                  </ul>
                </div>

                {/* Frontend Spec */}
                <div className="rounded-lg border p-3.5 sm:p-4 space-y-3 bg-muted/10">
                  <div className="flex items-center justify-between">
                    <span className="font-semibold text-xs sm:text-sm flex items-center gap-2 text-foreground">
                      <Cpu className="size-4 text-blue-500" />
                      Frontend Console
                    </span>
                    <Badge variant="outline" className="text-[10px] sm:text-[11px] font-mono">
                      Next.js 16
                    </Badge>
                  </div>
                  <ul className="space-y-2 text-xs text-muted-foreground">
                    <li className="flex flex-col xs:flex-row xs:items-center justify-between gap-0.5 xs:gap-2 py-0.5 border-b border-border/40">
                      <span>Framework:</span>
                      <span className="font-mono text-foreground font-medium">Next.js 16 (App Router)</span>
                    </li>
                    <li className="flex flex-col xs:flex-row xs:items-center justify-between gap-0.5 xs:gap-2 py-0.5 border-b border-border/40">
                      <span>UI Library:</span>
                      <span className="font-mono text-foreground font-medium">React 19 + TypeScript 5</span>
                    </li>
                    <li className="flex flex-col xs:flex-row xs:items-center justify-between gap-0.5 xs:gap-2 py-0.5 border-b border-border/40">
                      <span>Design System:</span>
                      <span className="font-mono text-foreground font-medium">Tailwind CSS v4 + Base UI</span>
                    </li>
                    <li className="flex flex-col xs:flex-row xs:items-center justify-between gap-0.5 xs:gap-2 py-0.5">
                      <span>State & Sync:</span>
                      <span className="font-mono text-foreground font-medium">SWR (stale-while-revalidate)</span>
                    </li>
                  </ul>
                </div>
              </div>

              {/* Execution Environments */}
              <div className="space-y-2.5 sm:space-y-3">
                <h3 className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                  Runtime Environments
                </h3>
                <dl className="divide-y rounded-lg border text-xs">
                  <div className="flex flex-col sm:grid sm:grid-cols-[160px_1fr] items-start sm:items-center gap-1.5 sm:gap-2 p-3 sm:p-3.5">
                    <dt className="font-medium text-foreground">Unified Production</dt>
                    <dd className="text-muted-foreground leading-relaxed">
                      A single process running on port <code className="font-mono bg-muted px-1 py-0.5 rounded text-foreground">:4793</code>.
                      The Next.js frontend export is embedded directly into the binary at build time and served from in-memory cache.
                    </dd>
                  </div>
                  <div className="flex flex-col sm:grid sm:grid-cols-[160px_1fr] items-start sm:items-center gap-1.5 sm:gap-2 p-3 sm:p-3.5">
                    <dt className="font-medium text-foreground">Dual-Port Development</dt>
                    <dd className="text-muted-foreground leading-relaxed">
                      The V backend runs on port <code className="font-mono bg-muted px-1 py-0.5 rounded text-foreground">:4793</code>,
                      while Next.js dev server with hot module reloading runs on port <code className="font-mono bg-muted px-1 py-0.5 rounded text-foreground">:4794</code> (proxying <code className="font-mono bg-muted px-1 py-0.5 rounded text-foreground">/api</code> requests to backend).
                    </dd>
                  </div>
                </dl>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* ===================== TAB 3: CHANGELOG ===================== */}
        <TabsContent value="changelog" className="space-y-4 sm:space-y-6">
          <Card>
            <CardHeader className="border-b bg-muted/15 px-4 py-3.5 sm:px-6 sm:py-4">
              <div className="flex items-center gap-2.5 sm:gap-3">
                <div className="flex size-8 sm:size-9 items-center justify-center rounded-lg bg-amber-500/10 text-amber-600 dark:text-amber-400 shrink-0">
                  <History className="size-4 sm:size-5" />
                </div>
                <div>
                  <CardTitle className="text-sm sm:text-lg">Release History</CardTitle>
                  <CardDescription className="text-xs sm:text-sm">
                    Summary of updates, improvements, and changes across releases
                  </CardDescription>
                </div>
              </div>
            </CardHeader>
            <CardContent className="space-y-4 sm:space-y-6 p-4 sm:p-6">
              {/* Current Release */}
              <div className="relative border-l-2 border-primary/40 pl-4 sm:pl-6 space-y-2.5 sm:space-y-3">
                <div className="absolute -left-[5px] top-1.5 size-2.5 rounded-full border-2 border-primary bg-background" />

                <div className="flex flex-wrap items-center gap-2">
                  <span className="font-mono text-sm sm:text-base font-semibold text-foreground">v{APP_VERSION}</span>
                  <Badge variant="outline" className="border-emerald-500/40 bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 text-[10px] sm:text-[11px]">
                    Current Release
                  </Badge>
                  <span className="text-[11px] sm:text-xs text-muted-foreground">• Active Deployment</span>
                </div>

                <div className="space-y-2 text-xs text-muted-foreground">
                  <p className="text-foreground font-medium">Production release of the iPXE ZTP server with core features:</p>
                  <ul className="list-disc pl-4 space-y-1.5 leading-relaxed">
                    <li>Single self-contained binary packaging V/veb backend and Next.js 16 frontend.</li>
                    <li>Zero-touch bare-metal machine discovery and MAC address approval workflow.</li>
                    <li>Dynamic iPXE boot script generation (<code className="font-mono bg-muted px-1 py-0.5 rounded text-[11px]">/boot.ipxe</code>) with state handling.</li>
                    <li>Ubuntu 24.04.5 LTS and 26.04.1 autoinstall provisioning via NFS root boot.</li>
                    <li>Flexible disk storage profiles: Direct (ext4), ZFS root with low-RAM ARC tuning, and LVM.</li>
                    <li>Modern web administration dashboard with machine lifecycle statuses and approval drawer.</li>
                    <li>Real-time RSS process memory diagnostics and server uptime tracking.</li>
                  </ul>
                </div>
              </div>

              {/* Releases link note */}
              <div className="rounded-lg border border-dashed p-3.5 sm:p-4 text-xs text-muted-foreground bg-muted/5 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
                <span>Detailed release notes and change logs for all releases are available on GitHub.</span>
                <a
                  href={`${GITHUB_REPO_URL}/releases`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className={cn(
                    buttonVariants({ variant: 'outline', size: 'sm' }),
                    'h-8 text-xs font-medium w-full sm:w-auto justify-center'
                  )}
                >
                  <span>View all releases on GitHub</span>
                  <ExternalLink className="size-3 ml-1 opacity-60" />
                </a>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* ===================== TAB 4: UPDATES ===================== */}
        <TabsContent value="updates" className="space-y-4 sm:space-y-6">
          <Card>
            <CardHeader className="border-b bg-muted/15 px-4 py-3.5 sm:px-6 sm:py-4">
              <div className="flex items-center gap-2.5 sm:gap-3">
                <div className="flex size-8 sm:size-9 items-center justify-center rounded-lg bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 shrink-0">
                  <RefreshCw className="size-4 sm:size-5" />
                </div>
                <div>
                  <CardTitle className="text-sm sm:text-lg">Software Updates</CardTitle>
                  <CardDescription className="text-xs sm:text-sm">
                    Current version status and release verification
                  </CardDescription>
                </div>
              </div>
            </CardHeader>
            <CardContent className="space-y-4 sm:space-y-6 p-4 sm:p-6">
              {/* Current Version Status */}
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 sm:gap-4 rounded-xl border bg-card p-3.5 sm:p-4 shadow-xs">
                <div className="space-y-1">
                  <div className="flex items-center gap-2">
                    <span className="text-xs sm:text-sm font-semibold text-foreground">Installed Version</span>
                    <Badge variant="outline" className="border-emerald-500/40 bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 font-mono text-[11px] sm:text-xs">
                      v{APP_VERSION}
                    </Badge>
                  </div>
                  <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
                    <CheckCircle2 className="size-3.5 text-emerald-500 shrink-0" />
                    <span>Your installation is currently running version {APP_VERSION}.</span>
                  </div>
                </div>

                <div className="flex items-center pt-1 sm:pt-0">
                  <Button variant="outline" size="sm" disabled className="h-9 sm:h-8 gap-1.5 text-xs font-medium opacity-60 w-full sm:w-auto justify-center">
                    <RefreshCw className="size-3.5" />
                    <span>Check for updates</span>
                  </Button>
                </div>
              </div>

              {/* Placeholder Notification Box */}
              <div className="rounded-lg border bg-muted/20 p-3.5 sm:p-4 space-y-1.5 sm:space-y-2">
                <div className="flex items-center gap-2 text-xs font-medium text-foreground">
                  <Info className="size-4 text-muted-foreground shrink-0" />
                  <span>Update Checking Status</span>
                </div>
                <p className="text-xs text-muted-foreground leading-relaxed">
                  Automatic in-app update checking and release notifications will be available in an upcoming release.
                  In the meantime, you can check for new releases and read commit logs directly on GitHub.
                </p>
              </div>

              {/* External Links */}
              <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-2 sm:gap-3 pt-1 sm:pt-2">
                <a
                  href={`${GITHUB_REPO_URL}/releases`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className={cn(
                    buttonVariants({ variant: 'outline', size: 'sm' }),
                    'h-9 sm:h-8 gap-1.5 text-xs font-medium justify-center w-full sm:w-auto'
                  )}
                >
                  <GitBranch className="size-3.5" />
                  <span>View GitHub Releases</span>
                  <ExternalLink className="size-3 opacity-60" />
                </a>
                <a
                  href={`${GITHUB_REPO_URL}/commits/main`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className={cn(
                    buttonVariants({ variant: 'ghost', size: 'sm' }),
                    'h-9 sm:h-8 gap-1.5 text-xs font-medium text-muted-foreground hover:text-foreground justify-center w-full sm:w-auto'
                  )}
                >
                  <History className="size-3.5" />
                  <span>View Commit History</span>
                  <ExternalLink className="size-3 opacity-60" />
                </a>
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  )
}

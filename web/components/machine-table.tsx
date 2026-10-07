'use client'

import { useState } from 'react'
import {
  CheckIcon,
  CircleCheckIcon,
  ClockIcon,
  InboxIcon,
  Loader2Icon,
  PackageCheckIcon,
  PencilIcon,
  RotateCwIcon,
  Trash2Icon,
  type LucideIcon,
} from 'lucide-react'
import { toast } from 'sonner'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { ConfirmDialog } from '@/components/confirm-dialog'
import { Skeleton } from '@/components/ui/skeleton'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { useMachines } from '@/hooks/use-machines'
import { apiErrorMessage } from '@/lib/api'
import { relTime } from '@/lib/format'
import type { Machine, MachineStatus } from '@/lib/types'

const STATUS_CLASSES: Record<MachineStatus, string> = {
  pending: 'bg-amber-100 text-amber-900 dark:bg-amber-950 dark:text-amber-200',
  approved: 'bg-blue-100 text-blue-900 dark:bg-blue-950 dark:text-blue-200',
  installing: 'bg-sky-100 text-sky-900 dark:bg-sky-950 dark:text-sky-200',
  installed: 'bg-green-100 text-green-900 dark:bg-green-950 dark:text-green-200',
}

const STATUS_ICONS: Record<MachineStatus, LucideIcon> = {
  pending: ClockIcon,
  approved: CircleCheckIcon,
  installing: Loader2Icon,
  installed: PackageCheckIcon,
}

interface MachineTableProps {
  onEdit: (machine: Machine) => void
  onApprove: (machine: Machine) => void
}

type ConfirmState = {
  kind: 'reinstall' | 'delete'
  machine: Machine
}

export function MachineTable({ onEdit, onApprove }: MachineTableProps) {
  const { list, loading, reinstall, markInstalled, remove } = useMachines()
  const [confirm, setConfirm] = useState<ConfirmState | null>(null)

  async function onMarkInstalled(machine: Machine) {
    try {
      await markInstalled(machine.id)
      toast.success(`${machine.hostname || machine.mac} marked as installed`)
    } catch (err) {
      toast.error(apiErrorMessage(err))
    }
  }

  async function onConfirm() {
    if (!confirm) return
    const machine = confirm.machine
    try {
      if (confirm.kind === 'reinstall') {
        await reinstall(machine.id)
        toast.success(`Reinstall armed for ${machine.hostname || machine.mac}`)
      } else {
        await remove(machine.id)
        toast.success(`Deleted ${machine.hostname || machine.mac}`)
      }
    } catch (err) {
      toast.error(apiErrorMessage(err))
    }
    setConfirm(null)
  }

  return (
    <>
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>MAC</TableHead>
            <TableHead>Hostname</TableHead>
            <TableHead>Status</TableHead>
            <TableHead>OS</TableHead>
            <TableHead>Boot</TableHead>
            <TableHead>Storage</TableHead>
            <TableHead>Last seen</TableHead>
            <TableHead className="w-[320px]">Actions</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {loading && list.length === 0 ? (
            Array.from({ length: 3 }).map((_, i) => (
              <TableRow key={i}>
                <TableCell colSpan={8}>
                  <Skeleton className="h-6 w-full" />
                </TableCell>
              </TableRow>
            ))
          ) : list.length === 0 ? (
            <TableRow className="hover:bg-transparent">
              <TableCell colSpan={8} className="h-40">
                <div className="flex flex-col items-center justify-center gap-2 text-muted-foreground">
                  <InboxIcon className="size-8 opacity-60" />
                  <div className="text-sm font-medium">No machines yet</div>
                  <div className="text-xs">Add a machine to start ZTP provisioning.</div>
                </div>
              </TableCell>
            </TableRow>
          ) : (
            list.map((row) => {
              const StatusIcon = STATUS_ICONS[row.status]
              return (
                <TableRow key={row.id}>
                  <TableCell className="font-mono">{row.mac}</TableCell>
                  <TableCell>{row.hostname || '—'}</TableCell>
                  <TableCell>
                    <Badge className={STATUS_CLASSES[row.status]}>
                      <StatusIcon
                        data-icon="inline-start"
                        className={row.status === 'installing' ? 'animate-spin' : undefined}
                      />
                      {row.status}
                    </Badge>
                  </TableCell>
                  <TableCell>
                    {row.os_name} {row.os_version}
                  </TableCell>
                  <TableCell>{row.boot_mode.toUpperCase()}</TableCell>
                  <TableCell>
                    {row.storage_layout}
                    {row.storage_disk ? (
                      <span className="text-muted-foreground"> · {row.storage_disk}</span>
                    ) : null}
                  </TableCell>
                  <TableCell>{relTime(row.last_seen_at)}</TableCell>
                  <TableCell>
                    <div className="flex flex-wrap gap-2">
                      <Button size="sm" variant="outline" onClick={() => onEdit(row)}>
                        <PencilIcon data-icon="inline-start" />
                        Edit
                      </Button>
                      {row.status === 'pending' && (
                        <Button size="sm" onClick={() => onApprove(row)}>
                          <CheckIcon data-icon="inline-start" />
                          Approve
                        </Button>
                      )}
                      {(row.status === 'installed' || row.status === 'installing') && (
                        <Button
                          size="sm"
                          variant="secondary"
                          onClick={() => setConfirm({ kind: 'reinstall', machine: row })}
                        >
                          <RotateCwIcon data-icon="inline-start" />
                          Reinstall
                        </Button>
                      )}
                      {row.status === 'installing' && (
                        <Button size="sm" variant="outline" onClick={() => onMarkInstalled(row)}>
                          <PackageCheckIcon data-icon="inline-start" />
                          Mark installed
                        </Button>
                      )}
                      <Button
                        size="sm"
                        variant="destructive"
                        onClick={() => setConfirm({ kind: 'delete', machine: row })}
                      >
                        <Trash2Icon data-icon="inline-start" />
                        Delete
                      </Button>
                    </div>
                  </TableCell>
                </TableRow>
              )
            })
          )}
        </TableBody>
      </Table>
      <ConfirmDialog
        open={confirm !== null}
        onOpenChange={(open) => {
          if (!open) setConfirm(null)
        }}
        title={confirm?.kind === 'delete' ? 'Delete machine' : 'Reinstall'}
        description={
          confirm
            ? confirm.kind === 'delete'
              ? `Delete ${confirm.machine.hostname || confirm.machine.mac}?`
              : `Re-arm the installer for ${confirm.machine.hostname || confirm.machine.mac}?`
            : ''
        }
        confirmLabel={confirm?.kind === 'delete' ? 'Delete' : 'Reinstall'}
        destructive={confirm?.kind === 'delete'}
        onConfirm={onConfirm}
      />
    </>
  )
}

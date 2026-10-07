'use client'

import { useEffect, useState } from 'react'
import { PlusIcon, RefreshCwIcon, TriangleAlertIcon } from 'lucide-react'
import { toast } from 'sonner'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Button } from '@/components/ui/button'
import { Card, CardAction, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { MachineSheet, type MachineSheetMode } from '@/components/machine-sheet'
import { MachineTable } from '@/components/machine-table'
import { useMachines } from '@/hooks/use-machines'
import { apiErrorMessage } from '@/lib/api'
import type { Machine } from '@/lib/types'

export default function MachinesPage() {
  const { pendingCount, error, mutate } = useMachines()
  const [sheetOpen, setSheetOpen] = useState(false)
  const [sheetMachine, setSheetMachine] = useState<Machine | null>(null)
  const [sheetMode, setSheetMode] = useState<MachineSheetMode>('edit')

  useEffect(() => {
    if (error) toast.error(apiErrorMessage(error))
  }, [error])

  function openCreate() {
    setSheetMachine(null)
    setSheetMode('create')
    setSheetOpen(true)
  }

  function openEdit(machine: Machine) {
    setSheetMachine(machine)
    setSheetMode('edit')
    setSheetOpen(true)
  }

  function openApprove(machine: Machine) {
    setSheetMachine(machine)
    setSheetMode('approve')
    setSheetOpen(true)
  }

  return (
    <div className="mx-auto max-w-[1200px] space-y-4">
      {pendingCount > 0 && (
        <Alert className="border-amber-300 bg-amber-50 text-amber-900 dark:border-amber-900 dark:bg-amber-950/40 dark:text-amber-200">
          <TriangleAlertIcon />
          <AlertDescription className="text-amber-900 dark:text-amber-200">
            {pendingCount} machine(s) waiting for approval. Approve them to start the OS
            installation on their next boot.
          </AlertDescription>
        </Alert>
      )}
      <Card>
        <CardHeader>
          <CardTitle>Machines</CardTitle>
          <CardAction className="flex gap-2">
            <Button
              size="sm"
              variant="outline"
              onClick={() => {
                mutate().catch(() => {})
              }}
            >
              <RefreshCwIcon data-icon="inline-start" />
              Refresh
            </Button>
            <Button size="sm" onClick={openCreate}>
              <PlusIcon data-icon="inline-start" />
              Add machine
            </Button>
          </CardAction>
        </CardHeader>
        <CardContent>
          <MachineTable onEdit={openEdit} onApprove={openApprove} />
        </CardContent>
      </Card>
      <MachineSheet
        open={sheetOpen}
        onOpenChange={setSheetOpen}
        machine={sheetMachine}
        mode={sheetMode}
      />
    </div>
  )
}

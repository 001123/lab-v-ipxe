<script setup lang="ts">
import { computed, h, onMounted, onUnmounted, ref } from 'vue'
import {
  NButton,
  NCard,
  NDataTable,
  NSpace,
  NTag,
  NPopconfirm,
  NAlert,
  useMessage,
  type DataTableColumns,
} from 'naive-ui'
import { useMachinesStore } from '../stores/machines'
import type { Machine } from '../api/types'
import { apiErrorMessage } from '../api/client'
import MachineDrawer from '../components/MachineDrawer.vue'

const store = useMachinesStore()
const message = useMessage()

const drawerShow = ref(false)
const drawerMachine = ref<Machine | null>(null)
const drawerMode = ref<'edit' | 'approve' | 'create'>('edit')

const statusType: Record<string, 'warning' | 'info' | 'primary' | 'success' | 'error'> = {
  pending: 'warning',
  approved: 'primary',
  installing: 'info',
  installed: 'success',
}

function relTime(ts: number): string {
  if (!ts) return '—'
  const diff = Date.now() / 1000 - ts
  if (diff < 60) return `${Math.max(1, Math.floor(diff))}s ago`
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`
  return `${Math.floor(diff / 86400)}d ago`
}

function openEdit(row: Machine) {
  drawerMachine.value = row
  drawerMode.value = 'edit'
  drawerShow.value = true
}

function openApprove(row: Machine) {
  drawerMachine.value = row
  drawerMode.value = 'approve'
  drawerShow.value = true
}

function openCreate() {
  drawerMachine.value = null
  drawerMode.value = 'create'
  drawerShow.value = true
}

async function onReinstall(row: Machine) {
  try {
    await store.reinstall(row.id)
    message.success(`Reinstall armed for ${row.hostname || row.mac}`)
  } catch (err) {
    message.error(apiErrorMessage(err))
  }
}

async function onMarkInstalled(row: Machine) {
  try {
    await store.markInstalled(row.id)
    message.success(`${row.hostname || row.mac} marked as installed`)
  } catch (err) {
    message.error(apiErrorMessage(err))
  }
}

async function onDelete(row: Machine) {
  try {
    await store.remove(row.id)
    message.success(`Deleted ${row.hostname || row.mac}`)
  } catch (err) {
    message.error(apiErrorMessage(err))
  }
}

const columns = computed<DataTableColumns<Machine>>(() => [
  {
    title: 'MAC',
    key: 'mac',
    render: (row) => h('span', { class: 'mono' }, row.mac),
  },
  { title: 'Hostname', key: 'hostname', render: (row) => row.hostname || '—' },
  {
    title: 'Status',
    key: 'status',
    render: (row) =>
      h(
        NTag,
        { type: statusType[row.status] || 'default', size: 'small', bordered: false },
        { default: () => row.status },
      ),
  },
  {
    title: 'OS',
    key: 'os',
    render: (row) => `${row.os_name} ${row.os_version}`,
  },
  {
    title: 'Boot',
    key: 'boot_mode',
    render: (row) => row.boot_mode.toUpperCase(),
  },
  {
    title: 'Storage',
    key: 'storage_layout',
    render: (row) => row.storage_layout,
  },
  { title: 'Last seen', key: 'last_seen_at', render: (row) => relTime(row.last_seen_at) },
  {
    title: 'Actions',
    key: 'actions',
    width: 320,
    render: (row) =>
      h(NSpace, { size: 8 }, () => {
        const buttons = [
          h(NButton, { size: 'small', onClick: () => openEdit(row) }, { default: () => 'Edit' }),
        ]
        if (row.status === 'pending') {
          buttons.push(
            h(
              NButton,
              { size: 'small', type: 'primary', onClick: () => openApprove(row) },
              { default: () => 'Approve' },
            ),
          )
        }
        if (row.status === 'installed' || row.status === 'installing') {
          buttons.push(
            h(
              NPopconfirm,
              { onPositiveClick: () => onReinstall(row) },
              {
                trigger: () =>
                  h(NButton, { size: 'small', type: 'warning', ghost: true }, { default: () => 'Reinstall' }),
                default: () => `Re-arm the installer for ${row.hostname || row.mac}?`,
              },
            ),
          )
        }
        if (row.status === 'installing') {
          buttons.push(
            h(
              NButton,
              { size: 'small', onClick: () => onMarkInstalled(row) },
              { default: () => 'Mark installed' },
            ),
          )
        }
        buttons.push(
          h(
            NPopconfirm,
            { onPositiveClick: () => onDelete(row) },
            {
              trigger: () =>
                h(NButton, { size: 'small', type: 'error', quaternary: true }, { default: () => 'Delete' }),
              default: () => `Delete ${row.hostname || row.mac}?`,
            },
          ),
        )
        return buttons
      }),
  },
])

let timer: number | undefined

onMounted(async () => {
  try {
    await store.fetchList()
  } catch (err) {
    message.error(apiErrorMessage(err))
  }
  timer = window.setInterval(() => {
    store.fetchList().catch(() => {})
  }, 5000)
})

onUnmounted(() => {
  if (timer) window.clearInterval(timer)
})
</script>

<template>
  <div class="page-card">
    <n-alert v-if="store.pendingCount > 0" type="warning" style="margin-bottom: 16px">
      {{ store.pendingCount }} machine(s) waiting for approval. Approve them to start the OS
      installation on their next boot.
    </n-alert>
    <n-card title="Machines">
      <template #header-extra>
        <n-space>
          <n-button size="small" @click="store.fetchList()">Refresh</n-button>
          <n-button size="small" type="primary" @click="openCreate">Add machine</n-button>
        </n-space>
      </template>
      <n-data-table
        :columns="columns"
        :data="store.list"
        :loading="store.loading"
        :bordered="false"
        :row-key="(row: Machine) => row.id"
      />
    </n-card>
    <MachineDrawer
      v-model:show="drawerShow"
      :machine="drawerMachine"
      :mode="drawerMode"
    />
  </div>
</template>

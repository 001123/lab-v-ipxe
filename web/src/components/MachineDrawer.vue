<script setup lang="ts">
import { ref, watch } from 'vue'
import {
  NDrawer,
  NDrawerContent,
  NForm,
  NFormItem,
  NInput,
  NSelect,
  NButton,
  NSpace,
  useMessage,
} from 'naive-ui'
import { useMachinesStore } from '../stores/machines'
import type { Machine, MachinePayload } from '../api/types'
import { apiErrorMessage } from '../api/client'

const props = defineProps<{
  show: boolean
  machine: Machine | null
  mode: 'edit' | 'approve' | 'create'
}>()

const emit = defineEmits<{
  (e: 'update:show', v: boolean): void
  (e: 'saved'): void
}>()

const store = useMachinesStore()
const message = useMessage()
const saving = ref(false)

const form = ref<MachinePayload>({})

watch(
  () => props.show,
  (show) => {
    if (!show) return
    const m = props.machine
    form.value = m
      ? {
          mac: m.mac,
          hostname: m.hostname,
          username: m.username,
          password: '',
          ssh_keys: m.ssh_keys,
          nfs_root: m.nfs_root,
          notes: m.notes,
          os_name: m.os_name,
          os_version: m.os_version,
          boot_mode: m.boot_mode,
          storage_layout: m.storage_layout,
        }
      : {
          mac: '',
          hostname: '',
          username: '',
          password: '',
          ssh_keys: '',
          nfs_root: '',
          notes: '',
          boot_mode: 'nfs',
          storage_layout: 'zfs',
        }
  },
)

function normalizeMacInput(v: string) {
  form.value.mac = v.toUpperCase().replace(/[^0-9A-F:.-]/g, '')
}

function isValidMac(v: string): boolean {
  const hex = v.replace(/[:.-]/g, '')
  return /^[0-9A-F]{12}$/.test(hex)
}

async function onSave() {
  const title = props.mode === 'create' ? 'Add machine' : props.machine?.hostname || 'machine'
  if (props.mode !== 'edit' && !form.value.mac) {
    message.warning('MAC address is required')
    return
  }
  if (form.value.mac && !isValidMac(form.value.mac)) {
    message.warning('Invalid MAC address')
    return
  }
  const effectiveHostname = props.mode === 'approve' ? form.value.hostname : undefined
  if (props.mode === 'approve' && !effectiveHostname) {
    message.warning('Hostname is required to approve')
    return
  }
  if (props.mode === 'create' && !form.value.hostname) {
    message.warning('Hostname is required')
    return
  }
  saving.value = true
  try {
    if (props.mode === 'create') {
      await store.create(form.value)
      message.success('Machine created')
    } else if (props.mode === 'approve' && props.machine) {
      await store.approve(props.machine.id, form.value)
      message.success(`Approved ${title}`)
    } else if (props.machine) {
      await store.update(props.machine.id, form.value)
      message.success('Saved')
    }
    emit('saved')
    emit('update:show', false)
  } catch (err) {
    message.error(apiErrorMessage(err))
  } finally {
    saving.value = false
  }
}

const bootModeOptions = [
  { label: 'NFS (via Proxmox NFS export)', value: 'nfs' },
  { label: 'Public HTTP (not implemented yet)', value: 'http', disabled: true },
]

const storageOptions = [
  { label: 'ZFS root', value: 'zfs' },
  { label: 'Direct (ext4)', value: 'direct' },
  { label: 'LVM', value: 'lvm' },
]
</script>

<template>
  <n-drawer
    :show="show"
    :width="480"
    @update:show="(v: boolean) => emit('update:show', v)"
  >
    <n-drawer-content
      :title="mode === 'create' ? 'Add machine' : mode === 'approve' ? 'Approve machine' : 'Edit machine'"
      closable
    >
      <n-form label-placement="top">
        <n-form-item label="MAC address">
          <n-input
            :value="form.mac"
            placeholder="BC:24:11:00:24:99"
            class="mono"
            :disabled="mode === 'edit' && !!machine"
            @update:value="normalizeMacInput"
          />
        </n-form-item>
        <n-form-item label="Hostname">
          <n-input v-model:value="form.hostname" placeholder="vm-ztp-test" />
        </n-form-item>
        <n-form-item label="Username">
          <n-input v-model:value="form.username" placeholder="ubuntu" />
        </n-form-item>
        <n-form-item :label="machine?.has_password ? 'Password (leave empty to keep current)' : 'Password (default: ubuntu)'">
          <n-input
            v-model:value="form.password"
            type="password"
            show-password-on="click"
            placeholder=""
          />
        </n-form-item>
        <n-form-item label="SSH authorized keys (one per line)">
          <n-input v-model:value="form.ssh_keys" type="textarea" :rows="3" placeholder="ssh-ed25519 AAAA... user@host" />
        </n-form-item>
        <n-form-item label="NFS root (empty = global default)">
          <n-input v-model:value="form.nfs_root" placeholder="192.168.250.4:/srv/nfs/ubuntu-24.04" class="mono" />
        </n-form-item>
        <n-form-item label="Boot mode">
          <n-select v-model:value="form.boot_mode" :options="bootModeOptions" />
        </n-form-item>
        <n-form-item label="Storage layout">
          <n-select v-model:value="form.storage_layout" :options="storageOptions" />
        </n-form-item>
        <n-form-item label="Notes">
          <n-input v-model:value="form.notes" type="textarea" :rows="2" placeholder="" />
        </n-form-item>
      </n-form>
      <template #footer>
        <n-space justify="end">
          <n-button @click="emit('update:show', false)">Cancel</n-button>
          <n-button type="primary" :loading="saving" @click="onSave">
            {{ mode === 'approve' ? 'Approve' : 'Save' }}
          </n-button>
        </n-space>
      </template>
    </n-drawer-content>
  </n-drawer>
</template>

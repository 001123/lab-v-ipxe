<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue'
import {
  NButton,
  NCard,
  NDescriptions,
  NDescriptionsItem,
  NForm,
  NFormItem,
  NInput,
  NProgress,
  NSpace,
  NTag,
  useMessage,
} from 'naive-ui'
import { useMachinesStore } from '../stores/machines'
import { apiErrorMessage } from '../api/client'

const store = useMachinesStore()
const message = useMessage()

const nfsRoot = ref('')
const ubuntuVersion = ref('')
const baseUrl = ref('')
const saving = ref(false)

const settings = computed(() => store.settings)
const assets = computed(() => store.settings?.assets)

const phaseType: Record<string, 'default' | 'info' | 'success' | 'warning' | 'error'> = {
  idle: 'default',
  downloading: 'info',
  extracting: 'warning',
  ready: 'success',
  failed: 'error',
}

function syncForm() {
  if (store.settings) {
    nfsRoot.value = store.settings.nfs_root_default
    ubuntuVersion.value = store.settings.ubuntu_version
    baseUrl.value = store.settings.base_url_override
  }
}

async function refresh() {
  try {
    await store.fetchSettings()
    syncForm()
  } catch (err) {
    message.error(apiErrorMessage(err))
  }
}

async function onSave() {
  saving.value = true
  try {
    await store.saveSettings({
      nfs_root_default: nfsRoot.value,
      ubuntu_version: ubuntuVersion.value,
      base_url_override: baseUrl.value,
    })
    message.success('Settings saved')
  } catch (err) {
    message.error(apiErrorMessage(err))
  } finally {
    saving.value = false
  }
}

async function onFetchAssets() {
  try {
    await store.fetchAssetsNow()
    message.success('Asset preparation started')
  } catch (err) {
    message.error(apiErrorMessage(err))
  }
}

let timer: number | undefined

onMounted(async () => {
  await refresh()
  timer = window.setInterval(() => {
    const phase = store.settings?.assets.phase
    if (phase === 'downloading' || phase === 'extracting') {
      store.fetchSettings().catch(() => {})
    }
  }, 2000)
})

onUnmounted(() => {
  if (timer) window.clearInterval(timer)
})
</script>

<template>
  <div class="page-card">
    <n-space vertical :size="16">
      <n-card title="Installer assets (Ubuntu kernel/initrd)">
        <template #header-extra>
          <n-space align="center">
            <n-tag :type="phaseType[assets?.phase || 'idle']" size="small" :bordered="false">
              {{ assets?.phase || 'idle' }}
            </n-tag>
            <n-button size="small" type="primary" @click="onFetchAssets">Fetch now</n-button>
          </n-space>
        </template>
        <n-space vertical>
          <div>{{ assets?.message || 'No asset operation yet.' }}</div>
          <n-progress
            v-if="assets && (assets.phase === 'downloading' || assets.phase === 'extracting')"
            type="line"
            :percentage="assets.percent"
            :status="assets.phase === 'extracting' ? 'warning' : 'info'"
          />
          <n-descriptions :column="1" size="small" label-placement="left" bordered>
            <n-descriptions-item label="Extractors available">
              {{ settings?.extractors.join(', ') || 'none (install xorriso / p7zip / libarchive)' }}
            </n-descriptions-item>
            <n-descriptions-item label="Source">{{ assets?.source || '—' }}</n-descriptions-item>
          </n-descriptions>
        </n-space>
      </n-card>

      <n-card title="Defaults">
        <n-form label-placement="left" label-width="180">
          <n-form-item label="NFS root default">
            <n-input v-model:value="nfsRoot" class="mono" placeholder="192.168.250.4:/srv/nfs/ubuntu-24.04" />
          </n-form-item>
          <n-form-item label="Ubuntu version">
            <n-input v-model:value="ubuntuVersion" placeholder="24.04" />
          </n-form-item>
          <n-form-item label="Base URL override">
            <n-input
              v-model:value="baseUrl"
              class="mono"
              placeholder="http://192.168.250.x:8080 (empty = use request Host)"
            />
          </n-form-item>
        </n-form>
        <template #footer>
          <n-space justify="end">
            <n-button :loading="saving" type="primary" @click="onSave">Save settings</n-button>
          </n-space>
        </template>
      </n-card>

      <n-card title="Server">
        <n-descriptions :column="1" size="small" label-placement="left" bordered>
          <n-descriptions-item label="Data directory">
            <span class="mono">{{ settings?.data_dir || '…' }}</span>
          </n-descriptions-item>
          <n-descriptions-item label="Database">
            <span class="mono">{{ settings?.db_path || '…' }}</span>
          </n-descriptions-item>
        </n-descriptions>
      </n-card>
    </n-space>
  </div>
</template>

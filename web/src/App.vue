<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  NConfigProvider,
  NDialogProvider,
  NGlobalStyle,
  NLayout,
  NLayoutHeader,
  NLayoutSider,
  NMenu,
  NMessageProvider,
  NButton,
  NSpace,
  NTag,
  darkTheme,
} from 'naive-ui'
import { useAuthStore } from './stores/auth'
import { useMachinesStore } from './stores/machines'

const auth = useAuthStore()
const machines = useMachinesStore()
const router = useRouter()
const route = useRoute()
const dark = ref(localStorage.getItem('labvipxe_dark') === '1')

const theme = computed(() => (dark.value ? darkTheme : null))

function toggleDark() {
  dark.value = !dark.value
  localStorage.setItem('labvipxe_dark', dark.value ? '1' : '0')
}

const menuOptions = computed(() => {
  const items = [
    { label: 'Machines', key: 'machines' },
    { label: 'Settings', key: 'settings' },
  ]
  if (machines.pendingCount > 0) {
    items[0].label = `Machines (${machines.pendingCount} pending)`
  }
  return items
})

async function onLogout() {
  await auth.logout()
  router.push('/login')
}

onMounted(async () => {
  if (auth.isAuthed && !auth.email) {
    try {
      await auth.fetchMe()
    } catch {
      // interceptor redirects to /login on 401
    }
  }
})
</script>

<template>
  <n-config-provider :theme="theme">
    <n-global-style />
    <n-message-provider>
      <n-dialog-provider>
        <n-layout v-if="auth.isAuthed && route.path !== '/login'" position="absolute">
          <n-layout-header bordered style="height: 56px; padding: 0 20px">
            <div style="display: flex; align-items: center; height: 100%; gap: 16px">
              <div style="font-weight: 600; font-size: 16px">lab-v-ipxe</div>
              <n-tag size="small" :bordered="false">ZTP provisioning</n-tag>
              <div style="flex: 1"></div>
              <n-space align="center">
                <span style="opacity: 0.7; font-size: 13px">{{ auth.email }}</span>
                <n-button size="small" quaternary @click="toggleDark">
                  {{ dark ? 'Light' : 'Dark' }}
                </n-button>
                <n-button size="small" quaternary @click="onLogout">Logout</n-button>
              </n-space>
            </div>
          </n-layout-header>
          <n-layout has-sider position="absolute" style="top: 56px">
            <n-layout-sider
              bordered
              :width="200"
              :native-scrollbar="false"
              content-style="padding: 12px 0"
            >
              <n-menu
                :value="(route.name as string) || 'machines'"
                :options="menuOptions"
                @update:value="(key: string) => router.push('/' + key)"
              />
            </n-layout-sider>
            <n-layout content-style="padding: 24px" :native-scrollbar="false">
              <router-view />
            </n-layout>
          </n-layout>
        </n-layout>
        <router-view v-else />
      </n-dialog-provider>
    </n-message-provider>
  </n-config-provider>
</template>

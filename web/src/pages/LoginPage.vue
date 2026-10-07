<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { NCard, NForm, NFormItem, NInput, NButton, useMessage } from 'naive-ui'
import { useAuthStore } from '../stores/auth'
import { apiErrorMessage } from '../api/client'

const auth = useAuthStore()
const router = useRouter()
const message = useMessage()

const email = ref('admin@ipxe.local')
const password = ref('')
const loading = ref(false)

async function onSubmit() {
  if (!email.value || !password.value) {
    message.warning('Enter email and password')
    return
  }
  loading.value = true
  try {
    await auth.login(email.value, password.value)
    router.push('/machines')
  } catch (err) {
    message.error(apiErrorMessage(err))
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div
    style="
      height: 100%;
      display: flex;
      align-items: center;
      justify-content: center;
      background: linear-gradient(135deg, #0f172a 0%, #1e3a5f 100%);
    "
  >
    <n-card title="lab-v-ipxe" style="width: 380px" :bordered="false">
      <template #header-extra>
        <span style="opacity: 0.6; font-size: 12px">ZTP provisioning server</span>
      </template>
      <n-form @submit.prevent="onSubmit">
        <n-form-item label="Email">
          <n-input v-model:value="email" placeholder="admin@ipxe.local" @keyup.enter="onSubmit" />
        </n-form-item>
        <n-form-item label="Password">
          <n-input
            v-model:value="password"
            type="password"
            show-password-on="click"
            placeholder="password"
            @keyup.enter="onSubmit"
          />
        </n-form-item>
        <n-button type="primary" block :loading="loading" @click="onSubmit">Sign in</n-button>
      </n-form>
    </n-card>
  </div>
</template>

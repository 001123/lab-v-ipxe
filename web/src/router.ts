import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from './stores/auth'
import LoginPage from './pages/LoginPage.vue'
import MachinesPage from './pages/MachinesPage.vue'
import SettingsPage from './pages/SettingsPage.vue'

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', redirect: '/machines' },
    { path: '/login', name: 'login', component: LoginPage },
    { path: '/machines', name: 'machines', component: MachinesPage },
    { path: '/settings', name: 'settings', component: SettingsPage },
  ],
})

router.beforeEach((to) => {
  const auth = useAuthStore()
  if (!auth.isAuthed && to.path !== '/login') {
    return { path: '/login' }
  }
  if (auth.isAuthed && to.path === '/login') {
    return { path: '/machines' }
  }
  return true
})

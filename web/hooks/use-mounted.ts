'use client'

import { useSyncExternalStore } from 'react'

const emptySubscribe = () => () => {}

// false during the server render and the hydration render, true afterwards
export function useMounted(): boolean {
  return useSyncExternalStore(
    emptySubscribe,
    () => true,
    () => false,
  )
}

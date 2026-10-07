'use client'

import { useEffect } from 'react'
import { ThemeProvider as NextThemesProvider, useTheme } from 'next-themes'

// The Vue app stored the theme as '1'/'0'; rewrite it to 'dark'/'light' once.
function LegacyThemeMigration() {
  const { setTheme } = useTheme()
  useEffect(() => {
    const legacy = localStorage.getItem('labvipxe_dark')
    if (legacy === '1' || legacy === '0') {
      setTheme(legacy === '1' ? 'dark' : 'light')
    }
  }, [setTheme])
  return null
}

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  return (
    <NextThemesProvider
      attribute="class"
      defaultTheme="light"
      enableSystem={false}
      storageKey="labvipxe_dark"
      disableTransitionOnChange
    >
      <LegacyThemeMigration />
      {children}
    </NextThemesProvider>
  )
}

'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { Skeleton } from '@/components/ui/skeleton'

export default function Home() {
  const router = useRouter()

  useEffect(() => {
    const token = localStorage.getItem('labvipxe_token')
    router.replace(token ? '/machines' : '/login')
  }, [router])

  return (
    <div className="p-6">
      <Skeleton className="h-8 w-56" />
    </div>
  )
}

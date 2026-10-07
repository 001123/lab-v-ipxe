import Link from 'next/link'
import { ArrowLeftIcon, FileQuestionIcon } from 'lucide-react'
import { Button } from '@/components/ui/button'

export default function NotFound() {
  return (
    <div className="flex min-h-dvh flex-col items-center justify-center gap-4">
      <FileQuestionIcon className="size-10 text-muted-foreground" />
      <div className="text-lg font-medium">Page not found</div>
      <Button render={<Link href="/" prefetch={false} />} variant="outline">
        <ArrowLeftIcon data-icon="inline-start" />
        Back to home
      </Button>
    </div>
  )
}

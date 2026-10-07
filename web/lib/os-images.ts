import type { OsImage, ProviderInfo } from '@/lib/types'

export function imageLabel(img: OsImage, providers: ProviderInfo[]): string {
  const provider = providers.find((p) => p.name === img.os_name)
  return `${provider?.display_name ?? img.os_name} ${img.version}`
}

export function defaultImage(images: OsImage[]): OsImage | undefined {
  return images.find((img) => img.is_default) ?? images[0]
}

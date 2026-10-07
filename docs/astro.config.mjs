// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  site: 'https://001123.github.io',
  integrations: [
    starlight({
      title: 'iPXE ZTP Docs',
      defaultLocale: 'en',
      locales: {
        en: {
          label: 'English',
          lang: 'en',
        },
        vi: {
          label: 'Tiếng Việt',
          lang: 'vi',
        },
      },
      logo: {
        src: './src/assets/logo.svg',
      },
      favicon: '/favicon.svg',
      social: [
        {
          icon: 'github',
          label: 'GitHub',
          href: 'https://github.com/001123/lab-v-ipxe',
        },
      ],
      customCss: ['./src/styles/custom.css'],
      components: {
        PageTitle: './src/components/PageTitle.astro',
        ThemeProvider: './src/components/ThemeProvider.astro',
        ThemeSelect: './src/components/ThemeSelect.astro',
      },
      head: [
        {
          tag: 'script',
          attrs: {
            src: '/scripts/cursor-effects.js',
            defer: true,
          },
        },
      ],
      editLink: {
        baseUrl: 'https://github.com/001123/lab-v-ipxe/edit/main/docs/',
      },
      sidebar: [
        {
          label: 'Getting Started',
          translations: {
            vi: 'Bắt Đầu',
          },
          items: [{ autogenerate: { directory: 'getting-started' } }],
        },
        {
          label: 'Architecture & Workflow',
          translations: {
            vi: 'Kiến Trúc & Quy Trình',
          },
          items: [{ autogenerate: { directory: 'architecture' } }],
        },
        {
          label: 'Guides',
          translations: {
            vi: 'Hướng Dẫn Vận Hành',
          },
          items: [{ autogenerate: { directory: 'guides' } }],
        },
        {
          label: 'Reference',
          translations: {
            vi: 'Tham Chiếu Kỹ Thuật',
          },
          items: [{ autogenerate: { directory: 'reference' } }],
        },
      ],
    }),
  ],
});

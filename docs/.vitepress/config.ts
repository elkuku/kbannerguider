import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'kBannerGuider',
  description: 'Ingress banner guide & mission navigator for Bannergress',
  base: '/kbannerguider/',

  head: [['link', { rel: 'icon', href: '/kbannerguider/logo.svg' }]],

  ignoreDeadLinks: [/\/coverage\//],

  themeConfig: {
    logo: '/logo.svg',

    nav: [
      { text: 'User Guide', link: '/user-guide' },
      { text: 'Architecture', link: '/architecture' },
      { text: 'API Reference', link: '/api-reference' },
      { text: 'Download', link: '/download' },
    ],

    sidebar: [
      {
        text: 'Getting Started',
        items: [
          { text: 'Overview', link: '/' },
          { text: 'User Guide', link: '/user-guide' },
          { text: 'Download', link: '/download' },
        ],
      },
      {
        text: 'Reference',
        items: [
          { text: 'API Reference', link: '/api-reference' },
          { text: 'Authentication', link: '/authentication' },
          { text: 'Data Models', link: '/data-models' },
          { text: 'Widget Reference', link: '/widget-reference' },
        ],
      },
      {
        text: 'Development',
        items: [
          { text: 'Architecture', link: '/architecture' },
          { text: 'Development Guide', link: '/development' },
        ],
      },
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/elkuku/kbannerguider' },
    ],

    footer: {
      message: 'For the <a href="https://ingress.com/" target="_blank">Ingress</a> community.',
      copyright: 'Powered by <a href="https://bannergress.com/" target="_blank">Bannergress</a>',
    },

    search: {
      provider: 'local',
    },
  },
})

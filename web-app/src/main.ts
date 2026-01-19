import { createApp, h } from 'vue'
import { createInertiaApp } from '@inertiajs/vue3'
import { createPinia } from 'pinia'
import './style.css'

const pinia = createPinia()

createInertiaApp({
  resolve: (name) => {
    const pages = import.meta.glob('./views/**/*.vue', { eager: true })
    return pages[`./views/${name}.vue`]
  },
  setup({ el, App, props, plugin }) {
    createApp({ render: () => h(App, props) })
      .use(plugin)
      .use(pinia)
      .mount(el)
  },
  progress: {
    color: '#0ea5e9',
  },
})

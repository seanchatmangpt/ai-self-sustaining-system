import { createApp } from 'vue'
import Counter from './components/Counter.vue'
import TraceFlow from './components/TraceFlow.vue'

// Export components for live_vue
export default {
  Counter,
  TraceFlow
}

// This will be used by live_vue for SSR and client-side rendering
export function createVueApp(component, props, ctx) {
  const app = createApp(component, props)
  
  // Add any global plugins, directives, or configurations here
  // app.use(SomePlugin)
  // app.directive('some-directive', SomeDirective)
  
  return app
}
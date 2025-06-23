import { defineBuildConfig } from 'unbuild';

export default defineBuildConfig({
  entries: [
    'module'
  ],
  declaration: true,
  clean: true,
  rollup: {
    emitCJS: true,
    inlineDependencies: true
  },
  externals: [
    '@nuxt/kit',
    '@nuxt/schema',
    'nuxt',
    'nitropack'
  ]
});
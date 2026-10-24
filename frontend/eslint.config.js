// @ts-check
const eslint = require('@eslint/js');
const { defineConfig } = require('eslint/config');
const tseslint = require('typescript-eslint');
const angular = require('angular-eslint');
const boundaries = require('eslint-plugin-boundaries');

module.exports = defineConfig([
  {
    ignores: ['dist/**', '.angular/**', 'node_modules/**', 'src/app/core/api/schema.d.ts'],
  },
  {
    files: ['**/*.ts'],
    extends: [eslint.configs.recommended, tseslint.configs.recommended, angular.configs.tsRecommended],
    processor: angular.processInlineTemplates,
    rules: {
      '@angular-eslint/directive-selector': 'off',
      '@angular-eslint/component-selector': 'off',
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
    },
  },
  {
    files: ['**/*.html'],
    extends: [angular.configs.templateRecommended],
    rules: {},
  },
  {
    files: ['src/**/*.ts'],
    ignores: ['src/**/*.spec.ts', 'src/**/testing/**'],
    plugins: { boundaries },
    settings: {
      'import/resolver': { typescript: { alwaysTryTypes: true, project: './tsconfig.json' } },
      'boundaries/include': ['src/app/{core,ui,shared,shell,dev,modules}/**/*.ts'],
      'boundaries/elements': [
        { type: 'core', pattern: 'src/app/core' },
        { type: 'ui', pattern: 'src/app/ui' },
        { type: 'shared', pattern: 'src/app/shared' },
        { type: 'shell', pattern: 'src/app/shell' },
        { type: 'dev', pattern: 'src/app/dev' },
        { type: 'module', pattern: 'src/app/modules/*', capture: ['moduleName'] },
      ],
    },
    rules: {
      'boundaries/dependencies': [
        'error',
        {
          default: 'disallow',
          message: '{{ from.element.types }} must not import {{ to.element.path }}',
          policies: [
            { allow: { to: { module: { origin: 'external' } } } },
            { allow: { to: { module: { origin: 'core' } } } },
            { from: { element: { type: 'shared' } }, allow: { to: { element: { type: 'shared' } } } },
            { from: { element: { type: 'ui' } }, allow: { to: { element: { types: { anyOf: ['ui', 'core', 'shared'] } } } } },
            { from: { element: { type: 'core' } }, allow: { to: { element: { types: { anyOf: ['core', 'ui', 'shared'] } } } } },
            {
              from: { element: { type: 'shell' } },
              allow: { to: { element: { types: { anyOf: ['shell', 'core', 'ui', 'shared'] } } } },
            },
            {
              from: { element: { type: 'dev' } },
              allow: { to: { element: { types: { anyOf: ['dev', 'core', 'ui', 'shared'] } } } },
            },
            {
              from: { element: { type: 'module' } },
              allow: { to: { element: { types: { anyOf: ['core', 'ui', 'shared'] } } } },
            },
            {
              from: { element: { type: 'module' } },
              allow: { to: { element: { type: 'module', captured: { moduleName: '{{ from.element.captured.moduleName }}' } } } },
            },
          ],
        },
      ],
    },
  },
]);

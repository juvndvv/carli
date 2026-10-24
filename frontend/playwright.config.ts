import { defineConfig, devices } from '@playwright/test';

const baseURL = process.env['E2E_BASE_URL'] ?? 'http://localhost:8180';

export default defineConfig({
  testDir: './e2e',
  testMatch: /.*\.(e2e|setup)\.ts$/,
  fullyParallel: false,
  workers: 1,
  retries: process.env['CI'] ? 1 : 0,
  timeout: 60_000,
  expect: { timeout: 10_000 },
  reporter: [['list'], ['html', { open: 'never', outputFolder: 'playwright-report' }]],
  outputDir: 'test-results',
  use: {
    baseURL,
    locale: 'es-ES',
    timezoneId: 'Europe/Madrid',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    { name: 'setup', testMatch: /auth\.setup\.ts$/ },
    {
      name: 'desktop',
      use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 900 }, storageState: 'e2e/.auth/demo.json' },
      dependencies: ['setup'],
      testMatch: /\.e2e\.ts$/,
      testIgnore: /mobile\.e2e\.ts$/,
    },
    {
      name: 'mobile',
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 390, height: 844 },
        isMobile: true,
        hasTouch: true,
        storageState: 'e2e/.auth/demo.json',
      },
      dependencies: ['setup'],
      testMatch: /mobile\.e2e\.ts$/,
    },
  ],
});

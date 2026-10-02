import { defineConfig, devices } from '@playwright/test';

const appUrl = process.env.APP_URL ?? 'http://localhost:8090';
const apiUrl = process.env.API_URL ?? 'http://localhost:8080';

export default defineConfig({
  testDir: './tests',
  timeout: 120_000,
  expect: { timeout: 15_000 },
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: [['list'], ['html', { open: 'never', outputFolder: 'playwright-report' }]],
  use: {
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    locale: 'ru-RU',
    timezoneId: 'Europe/Moscow',
  },
  projects: [
    {
      name: 'admin',
      testMatch: /admin\..*\.spec\.ts/,
      use: { ...devices['Desktop Chrome'], baseURL: apiUrl },
    },
    {
      name: 'app',
      testMatch: /app\..*\.spec\.ts/,
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 412, height: 915 },
        baseURL: appUrl,
        geolocation: { latitude: 55.7495, longitude: 37.5374 },
        permissions: ['geolocation'],
      },
    },
  ],
});

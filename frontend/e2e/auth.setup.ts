import { existsSync } from 'node:fs';
import { test as setup } from '@playwright/test';
import { login } from './support';

const STATE = 'e2e/.auth/demo.json';

setup('sign in as the demo user', async ({ browser }) => {
  if (existsSync(STATE)) {
    const reused = await browser.newContext({ storageState: STATE });
    const response = await reused.request.get('/api/v1/me', {
      headers: { Accept: 'application/json', Referer: `${setup.info().project.use.baseURL}/` },
    });
    await reused.close();
    if (response.ok()) {
      return;
    }
  }
  const context = await browser.newContext();
  const page = await context.newPage();
  await login(page);
  await context.storageState({ path: STATE });
  await context.close();
});

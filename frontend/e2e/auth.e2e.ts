import { expect, test } from '@playwright/test';
import { DEMO_EMAIL, login, trackConsoleErrors } from './support';

test.describe('authentication', () => {
  test.use({ storageState: { cookies: [], origins: [] } });

  test('redirects guests to the login page', async ({ page }) => {
    await page.goto('/finanzas');
    await expect(page).toHaveURL(/\/login\?redirect=/);
    await expect(page.getByRole('heading', { name: 'carli' })).toBeVisible();
  });

  test('rejects a wrong password with a Spanish message', async ({ page }) => {
    await page.goto('/login');
    await page.getByLabel('Email').fill(DEMO_EMAIL);
    await page.getByLabel('Contraseña').fill('not-the-password');
    await page.getByRole('button', { name: 'Entrar' }).click();
    await expect(page.getByRole('alert')).toContainText(/credenciales|contraseña|incorrect/i);
    await expect(page).toHaveURL(/\/login/);
  });

  test('signs in, lands on the launcher and signs out', async ({ page }) => {
    const errors = trackConsoleErrors(page);
    await login(page);
    await expect(page.getByRole('link', { name: /Finanzas/ }).first()).toBeVisible();
    await page.getByRole('button', { name: 'Cerrar sesión' }).click();
    await expect(page).toHaveURL(/\/login/);
    expect(errors).toEqual([]);
  });
});

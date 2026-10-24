import { expect, test } from '@playwright/test';

test('Ctrl+K opens the global search with the input focused so typing searches right away', async ({ page }) => {
  await page.goto('/finanzas');
  await expect(page.getByRole('heading', { name: 'Resumen' }).first()).toBeVisible();
  await page.keyboard.press('Control+k');
  const dialog = page.getByRole('dialog', { name: 'Búsqueda global' });
  await expect(dialog).toBeVisible();
  const input = dialog.getByRole('searchbox');
  await expect(input).toBeFocused();
  await page.keyboard.type('Mercad');
  await expect(input).toHaveValue('Mercad');
  await expect(dialog.getByRole('option').filter({ hasText: /Mercadona/ }).first()).toBeVisible();
  await page.keyboard.press('Escape');
});

test('form dialogs open with the first field focused instead of the close button', async ({ page }) => {
  await page.goto('/finanzas/cuentas');
  await page.getByRole('button', { name: 'Nueva cuenta' }).click();
  const dialog = page.getByRole('dialog', { name: 'Nueva cuenta' });
  await expect(dialog).toBeVisible();
  await expect(dialog.getByLabel('Nombre')).toBeFocused();
  await page.keyboard.press('Escape');
  await expect(dialog).toBeHidden();
});

test('the desktop sidebar keeps Ajustes and Cerrar sesión visible at 1280x800', async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 800 });
  await page.goto('/ajustes');
  const sidebar = page.getByRole('navigation', { name: 'Navegación principal' });
  await expect(sidebar.locator('a[href="/ajustes"]')).toBeInViewport({ ratio: 1 });
  await expect(sidebar.getByRole('button', { name: 'Cerrar sesión' })).toBeInViewport({ ratio: 1 });
});

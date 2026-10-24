import AxeBuilder from '@axe-core/playwright';
import { expect, test } from '@playwright/test';

const PAGES = [
  '/',
  '/finanzas',
  '/finanzas/movimientos',
  '/finanzas/cuentas',
  '/finanzas/presupuestos',
  '/finanzas/categorias',
  '/finanzas/recurrentes',
  '/finanzas/objetivos',
  '/finanzas/deudas',
  '/finanzas/compartidos',
  '/finanzas/ajustes',
  '/ajustes/perfil',
  '/ajustes/notificaciones',
  '/notificaciones',
];

for (const scheme of ['light', 'dark'] as const) {
  test.describe(`accessibility (${scheme})`, () => {
    test.use({ colorScheme: scheme });

    for (const path of PAGES) {
      test(`${path} has no serious or critical axe violations`, async ({ page }) => {
        await page.goto(path);
        await page.waitForLoadState('networkidle');
        await expect(page.locator('ui-skeleton')).toHaveCount(0, { timeout: 10_000 }).catch(() => undefined);
        const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa']).analyze();
        const blocking = results.violations
          .filter((violation) => violation.impact === 'serious' || violation.impact === 'critical')
          .map((violation) => ({
            id: violation.id,
            impact: violation.impact,
            targets: violation.nodes.slice(0, 5).map((node) => node.target.join(' ')),
          }));
        expect(blocking).toEqual([]);
      });
    }
  });
}

test('the login page has no serious or critical axe violations', async ({ browser }) => {
  const context = await browser.newContext({ storageState: { cookies: [], origins: [] } });
  const page = await context.newPage();
  await page.goto('/login');
  await page.getByLabel('Email').waitFor();
  const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21aa']).analyze();
  expect(results.violations.filter((violation) => ['serious', 'critical'].includes(violation.impact ?? ''))).toEqual([]);
  await context.close();
});

test('the transaction sheet dialog has no serious or critical axe violations', async ({ page }) => {
  await page.goto('/finanzas/movimientos');
  await page.getByRole('button', { name: 'Nuevo', exact: true }).click();
  const sheet = page.getByRole('dialog', { name: 'Nuevo movimiento' });
  await expect(sheet).toBeVisible();
  await sheet.getByRole('button', { name: /^Más opciones/ }).click();
  const results = await new AxeBuilder({ page }).include('[role="dialog"]').withTags(['wcag2a', 'wcag2aa', 'wcag21aa']).analyze();
  expect(results.violations.filter((violation) => ['serious', 'critical'].includes(violation.impact ?? ''))).toEqual([]);
});

test('the calendar in the open-period dialog has no serious axe violations and supports arrow keys', async ({ page }) => {
  await page.goto('/finanzas/ajustes');
  await page.getByRole('button', { name: 'Abrir periodo', exact: true }).click();
  const dialog = page.getByRole('dialog', { name: 'Abrir periodo a mano' });
  await expect(dialog).toBeVisible();
  const grid = dialog.getByRole('grid');
  await expect(grid.getByRole('row')).toHaveCount(7);
  await dialog.evaluate((element) => Promise.all(element.getAnimations({ subtree: true }).map((animation) => animation.finished)));
  const results = await new AxeBuilder({ page }).include('[role="dialog"]').withTags(['wcag2a', 'wcag2aa', 'wcag21aa']).analyze();
  expect(results.violations.filter((violation) => ['serious', 'critical'].includes(violation.impact ?? ''))).toEqual([]);

  const focusedDay = grid.locator('button[tabindex="0"]');
  await focusedDay.focus();
  const before = (await focusedDay.getAttribute('data-iso'))!;
  const next = new Date(`${before}T00:00:00Z`);
  next.setUTCDate(next.getUTCDate() + 1);
  await page.keyboard.press('ArrowRight');
  await expect(grid.locator(`button[data-iso="${next.toISOString().slice(0, 10)}"]`)).toBeFocused();
  await page.keyboard.press('Escape');
  await expect(dialog).toBeHidden();
});

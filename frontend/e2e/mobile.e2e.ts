import { expect, test } from '@playwright/test';
import { deleteTransaction, primaryAccount, TransactionDto } from './finance-api';
import { FinanceApi, trackConsoleErrors } from './support';

test('flow 1: quick-add an expense on a phone with default account and date', async ({ page }) => {
  const errors = trackConsoleErrors(page);
  await page.goto('/finanzas');
  const api = new FinanceApi(page);
  const settings = await api.get<{ data: { last_used_account_id: string | null; default_account_id: string | null } }>(
    'finance/settings',
  );
  const expectedAccount =
    settings.data.default_account_id ?? settings.data.last_used_account_id ?? (await primaryAccount(api)).id;

  await expect(page.getByRole('navigation').filter({ hasText: 'Movimientos' }).last()).toBeVisible();
  await page.getByRole('button', { name: 'Nuevo movimiento' }).click();

  const sheet = page.getByRole('dialog');
  await expect(sheet).toBeVisible();
  const box = await sheet.boundingBox();
  expect(box!.width).toBeLessThanOrEqual(390);
  const amount = sheet.getByLabel('Importe');
  await expect(amount).toBeFocused();
  const cents = 100 + Math.floor(Math.random() * 9000);
  await page.keyboard.type(`${Math.trunc(cents / 100)},${String(cents % 100).padStart(2, '0')}`);
  const category = sheet.getByRole('radiogroup', { name: /Categoría/ }).getByRole('radio').first();
  await category.click();
  await expect(category).toHaveAttribute('aria-checked', 'true');
  await expect(sheet.getByRole('button', { name: 'Guardar' })).toBeInViewport({ ratio: 1 });
  await sheet.getByRole('button', { name: 'Guardar' }).click();
  await expect(page.getByRole('status').filter({ hasText: 'Movimiento guardado' })).toBeVisible();

  const today = new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Madrid' });
  const { data } = await api.get<{ data: TransactionDto[] }>(`finance/transactions?from=${today}&to=${today}&per_page=20`);
  const created = data.find((item) => item.amount_cents === -cents);
  expect(created).toBeDefined();
  try {
    expect(created!.kind).toBe('expense');
    expect(created!.date).toBe(today);
    expect(created!.account_id).toBe(expectedAccount);
    expect(created!.category_id).not.toBeNull();
  } finally {
    await deleteTransaction(api, created!.id);
  }

  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
  expect(overflow).toBeLessThanOrEqual(0);
  expect(errors).toEqual([]);
});

test('budget category names are not truncated on a phone', async ({ page }) => {
  await page.goto('/finanzas/presupuestos');
  const names = page.locator('fin-budget-line .name');
  await expect(names.first()).toBeVisible();
  const clipped = await names.evaluateAll((elements) =>
    elements.filter((element) => element.scrollWidth > element.clientWidth).map((element) => element.textContent?.trim()),
  );
  expect(clipped).toEqual([]);
});

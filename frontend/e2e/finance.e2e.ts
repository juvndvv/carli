import { expect, test } from '@playwright/test';
import { AccountDto, deleteTransaction, TransactionDto } from './finance-api';
import { FinanceApi, trackConsoleErrors } from './support';

test('registers a transfer between two accounts from the sheet', async ({ page }) => {
  const errors = trackConsoleErrors(page);
  await page.goto('/finanzas/movimientos');
  const api = new FinanceApi(page);
  const { data: accounts } = await api.get<{ data: AccountDto[] }>('finance/accounts');
  const target = accounts.find((account) => account.type === 'savings')!;
  const before = target.balance_cents;

  await page.getByRole('button', { name: 'Nuevo', exact: true }).click();
  const sheet = page.getByRole('dialog');
  await sheet.getByRole('radio', { name: 'Transferencia' }).click();
  await sheet.getByLabel('Importe').fill('12,34');
  await sheet.locator('#' + (await sheet.getByText('Hacia', { exact: true }).getAttribute('for'))).click();
  await page.getByRole('option', { name: target.name }).click();
  await sheet.getByRole('button', { name: 'Guardar' }).click();
  await expect(page.getByRole('status').filter({ hasText: 'Movimiento guardado' })).toBeVisible();

  const { data: legs } = await api.get<{ data: TransactionDto[] }>(
    `finance/transactions?kind[]=transfer&account_id[]=${target.id}&per_page=1`,
  );
  try {
    expect(legs[0].amount_cents).toBe(1234);
    const { data: after } = await api.get<{ data: AccountDto }>(`finance/accounts/${target.id}`);
    expect(after.balance_cents).toBe(before + 1234);
  } finally {
    await deleteTransaction(api, legs[0].id);
  }
  expect(errors).toEqual([]);
});

test('the period selector moves the dashboard and budgets to the previous period', async ({ page }) => {
  const errors = trackConsoleErrors(page);
  await page.goto('/finanzas');
  const api = new FinanceApi(page);
  const { data: periods } = await api.get<{ data: { id: string; name: string; is_current: boolean }[] }>('finance/periods');
  test.skip(periods.length < 2, 'Needs two periods');
  const [current, previous] = periods;

  await expect(page.getByRole('button', { name: new RegExp(current.name) }).first()).toBeVisible();
  await page.getByRole('button', { name: 'Periodo anterior' }).click();
  await expect(page).toHaveURL(new RegExp(`periodo=${previous.id}`));
  await expect(page.getByRole('button', { name: new RegExp(previous.name) }).first()).toBeVisible();

  await page.goto(`/finanzas/presupuestos?periodo=${previous.id}`);
  await expect(page.getByRole('button', { name: new RegExp(previous.name) }).first()).toBeVisible();
  await expect(page.getByText('Resultado')).toBeVisible();
  expect(errors).toEqual([]);
});

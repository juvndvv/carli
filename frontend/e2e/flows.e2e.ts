import { expect, test } from '@playwright/test';
import {
  BudgetOverviewDto,
  centsToInput,
  ContactDto,
  deleteTransaction,
  findTransactionByPayee,
  primaryAccount,
  RecurringRuleDto,
  shiftIsoDate,
  TransactionDto,
} from './finance-api';
import { artisan, FinanceApi, trackConsoleErrors, uniqueLabel } from './support';

test.describe('PRD 7.3 main flows (desktop)', () => {
  test('flow 2: weekly review fixes uncategorized and pending movements, then reconciles', async ({ page }) => {
    const errors = trackConsoleErrors(page);
    await page.goto('/finanzas/movimientos');
    const api = new FinanceApi(page);
    const account = await primaryAccount(api);
    const payee = uniqueLabel('Revisión e2e');
    const created = await api.send<{ data: TransactionDto }>('POST', 'finance/transactions', {
      account_id: account.id,
      kind: 'expense',
      amount_cents: -1234,
      date: new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Madrid' }),
      payee,
      status: 'pending',
    });

    try {
      await page.goto('/finanzas/movimientos?categoria=none');
      await expect(page.getByRole('button', { name: /Sin categoría/ }).first()).toBeVisible();
      await expect(page.getByRole('button', { name: new RegExp(payee) })).toBeVisible();

      await page.goto('/finanzas/movimientos');
      await page.getByRole('button', { name: /^Pendientes/ }).click();
      await expect(page).toHaveURL(/estado=pendiente/);
      await page.getByRole('button', { name: new RegExp(payee) }).click();

      const sheet = page.getByRole('dialog');
      await sheet.getByRole('radiogroup', { name: /Categoría/ }).getByRole('radio').first().click();
      await sheet.getByRole('button', { name: /^Más opciones/ }).click();
      await sheet.getByRole('switch', { name: 'Pendiente de confirmar' }).click();
      await sheet.getByRole('button', { name: 'Guardar' }).click();
      await expect(page.getByRole('status').filter({ hasText: 'Cambios guardados' })).toBeVisible();

      const updated = await api.get<{ data: TransactionDto }>(`finance/transactions/${created.data.id}`);
      expect(updated.data.status).toBe('cleared');
      expect(updated.data.category_id).not.toBeNull();

      const before = await primaryAccount(api);
      await page.goto('/finanzas/cuentas');
      const card = page.locator('ui-card').filter({ has: page.getByText(before.name, { exact: true }) }).filter({
        has: page.getByRole('button', { name: 'Conciliar' }),
      });
      await card.first().getByRole('button', { name: 'Conciliar' }).click();
      const dialog = page.getByRole('dialog');
      await dialog.getByLabel('Saldo real en el banco').fill(centsToInput(before.cleared_balance_cents + 100));
      await dialog.getByRole('button', { name: 'Conciliar' }).click();
      await expect(page.getByRole('status').filter({ hasText: /Cuenta conciliada · ajuste de \+1,00/ })).toBeVisible();

      const after = await primaryAccount(api);
      expect(after.cleared_balance_cents).toBe(before.cleared_balance_cents + 100);
      expect(after.balance_cents).toBe(before.balance_cents + 100);
      const adjustments = await api.get<{ data: TransactionDto[] }>(
        `finance/transactions?kind[]=adjustment&account_id[]=${after.id}&per_page=1`,
      );
      await deleteTransaction(api, adjustments.data[0].id);
    } finally {
      await deleteTransaction(api, created.data.id);
    }
    expect(errors).toEqual([]);
  });

  test('flow 3: plan the period by copying budgets from the previous one and adjusting', async ({ page }) => {
    const errors = trackConsoleErrors(page);
    await page.goto('/finanzas/presupuestos');
    const api = new FinanceApi(page);
    const overview = await api.get<BudgetOverviewDto>('finance/budgets');
    const previous = overview.meta.previous_period;
    test.skip(!previous, 'Needs a previous period');
    const previousOverview = await api.get<BudgetOverviewDto>(`finance/budgets?period_id=${previous!.id}`);
    const target =
      overview.data.find((row) => row.category.name === 'Ropa') ??
      overview.data.find((row) => previousOverview.data.some((old) => old.category_id === row.category_id))!;
    const previousAmount = previousOverview.data.find((row) => row.category_id === target.category_id)!.amount_cents;

    await api.send('PUT', 'finance/budgets', { budgets: [{ category_id: target.category_id, amount_cents: null }] });
    try {
      await page.reload();
      const row = page.locator('button.budget').filter({ has: page.getByText(target.category.name, { exact: true }) });
      await expect(row).toHaveCount(0);

      await page.getByRole('button', { name: `Copiar de ${previous!.short_name}` }).first().click();
      await expect(
        page.getByRole('status').filter({ hasText: `1 presupuesto copiado de ${previous!.short_name}` }),
      ).toBeVisible();
      await expect(row).toContainText(centsToInput(previousAmount));

      await page.getByRole('button', { name: 'Editar' }).click();
      const dialog = page.getByRole('dialog', { name: /Editar presupuestos/ });
      const limit = dialog.getByLabel(`Límite de ${target.category.name}`);
      await limit.fill('123,45');
      await dialog.getByRole('button', { name: 'Guardar' }).click();
      await expect(page.getByRole('status').filter({ hasText: 'Presupuestos guardados' })).toBeVisible();
      await expect(row).toContainText('123,45');
    } finally {
      await api.send('PUT', 'finance/budgets', {
        budgets: [{ category_id: target.category_id, amount_cents: target.amount_cents }],
      });
    }
    expect(errors).toEqual([]);
  });

  test('flow 4: a subscription reminder lands in the inbox and leads to cancelling it', async ({ page }) => {
    const errors = trackConsoleErrors(page);
    await page.goto('/finanzas');
    const api = new FinanceApi(page);
    const { data: rules } = await api.get<{ data: RecurringRuleDto[] }>('finance/recurring-rules?subscriptions=1');
    const netflix = rules.find((rule) => rule.name === 'Netflix' && !rule.cancelled);
    test.skip(!netflix?.next_occurrence, 'Needs the demo Netflix subscription');

    const reminderDate = shiftIsoDate(netflix!.next_occurrence!, -2);
    artisan('finance:upcoming-charges', `--date=${reminderDate}`);
    await expect
      .poll(
        async () => {
          const inbox = await api.get<{ data: { title: string }[] }>('notifications?per_page=20');
          return inbox.data.some((item) => /^Netflix 13,99\s€ pasado mañana$/.test(item.title));
        },
        { timeout: 20_000 },
      )
      .toBe(true);

    try {
      await page.reload();
      await page.getByRole('button', { name: /^Notificaciones/ }).click();
      await page.getByRole('button', { name: /Netflix 13,99\s€ pasado mañana/ }).first().click();
      await expect(page).toHaveURL(/\/finanzas\/recurrentes/);

      await page.getByRole('button', { name: 'Acciones de Netflix' }).click();
      await page.getByRole('menuitem', { name: 'Cancelar suscripción' }).click();
      await expect(page.getByRole('status').filter({ hasText: 'Netflix cancelada' })).toBeVisible();
      const cancelled = await api.get<{ data: RecurringRuleDto }>(`finance/recurring-rules/${netflix!.id}`);
      expect(cancelled.data.cancelled).toBe(true);
    } finally {
      await api.send('PATCH', `finance/recurring-rules/${netflix!.id}`, { cancelled: false });
    }
    expect(errors).toEqual([]);
  });

  test('flow 5: a shared dinner of 80 € with Ana at 50 % leaves Ana owing 40 €', async ({ page }) => {
    const errors = trackConsoleErrors(page);
    await page.goto('/finanzas/movimientos');
    const api = new FinanceApi(page);
    const { data: contacts } = await api.get<{ data: ContactDto[] }>('finance/contacts');
    const ana = contacts.find((contact) => contact.name === 'Ana');
    test.skip(!ana, 'Needs the demo contact Ana');
    const payee = uniqueLabel('Cena e2e');

    await page.getByRole('button', { name: 'Nuevo', exact: true }).click();
    const sheet = page.getByRole('dialog');
    await sheet.getByLabel('Importe').fill('80');
    await sheet.getByRole('radiogroup', { name: /Categoría/ }).getByRole('radio').first().click();
    await sheet.getByLabel('Comercio o concepto').fill(payee);
    await sheet.getByRole('button', { name: /^Más opciones/ }).click();
    await sheet.getByRole('switch', { name: 'Gasto compartido' }).click();
    await sheet.getByRole('radio', { name: 'Porcentaje' }).click();
    await sheet.getByRole('group', { name: 'Con quién lo compartes' }).getByRole('button', { name: 'Ana' }).click();
    await sheet.getByLabel('Porcentaje de Ana').fill('50');
    await expect(sheet.getByText(/Ana te debe 40,00\s€/)).toBeVisible();
    await sheet.getByRole('button', { name: 'Guardar' }).click();
    await expect(page.getByRole('status').filter({ hasText: 'Movimiento guardado' })).toBeVisible();

    const transaction = await findTransactionByPayee(api, payee);
    expect(transaction).toBeDefined();
    try {
      expect(transaction!.amount_cents).toBe(-8000);
      expect(transaction!.shares).toEqual([expect.objectContaining({ contact_id: ana!.id, amount_cents: 4000 })]);
      const { data: after } = await api.get<{ data: ContactDto }>(`finance/contacts/${ana!.id}`);
      expect(after.balance_cents).toBe(ana!.balance_cents + 4000);

      await page.goto('/finanzas/compartidos');
      await page.getByRole('link', { name: /^Ana/ }).first().click();
      await expect(page).toHaveURL(new RegExp(`/finanzas/compartidos/${ana!.id}`));
      await expect(page.getByText(payee)).toBeVisible();
      await expect(page.locator('body')).toContainText(/40,00\s€/);
    } finally {
      await deleteTransaction(api, transaction!.id);
    }
    expect(errors).toEqual([]);
  });
});

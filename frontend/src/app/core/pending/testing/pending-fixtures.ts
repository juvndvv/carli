import { PendingItem, PendingSummary } from '../pending.models';

export function aPendingItem(overrides: Partial<PendingItem> = {}): PendingItem {
  return {
    module: 'finance',
    type: 'uncategorized_transaction',
    id: 'tx-1',
    title: 'Mercadona',
    subtitle: 'BBVA · Importado del banco',
    amount_cents: -4250,
    date: '2026-10-24',
    route: '/finanzas/movimientos?sin_categoria=1&periodo=todos',
    meta: { transaction_id: 'tx-1', kind: 'expense', source: 'bank' },
    ...overrides,
  };
}

export const aSummary = (uncategorized = 2, recurring = 1): PendingSummary => ({
  total: uncategorized + recurring,
  by_module: [
    { module: 'finance', module_name: 'Finanzas', type: 'uncategorized_transaction', count: uncategorized },
    { module: 'finance', module_name: 'Finanzas', type: 'recurring_to_confirm', count: recurring },
  ].filter((entry) => entry.count > 0),
});

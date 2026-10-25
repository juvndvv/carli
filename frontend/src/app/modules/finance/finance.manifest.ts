import { inject } from '@angular/core';
import { AppModuleManifest } from '@core/modules/app-module';
import { QuickAddOpener } from '@core/quick-add';
import { TransactionSheetLauncher } from './features/transactions/transaction-sheet.launcher';

export const FINANCE_BASE_PATH = '/finanzas';

export const FINANCE_PENDING = {
  uncategorized: 'uncategorized_transaction',
  recurring: 'recurring_to_confirm',
} as const;

export const financeManifest: AppModuleManifest = {
  id: 'finance',
  name: 'Finanzas',
  icon: 'wallet',
  basePath: FINANCE_BASE_PATH,
  description: 'Cuentas, movimientos, presupuestos y objetivos.',
  routes: () => import('./finance.routes').then((m) => m.financeRoutes),
  nav: [
    { label: 'Resumen', path: FINANCE_BASE_PATH, icon: 'layout-dashboard', exact: true, primary: true },
    { label: 'Movimientos', path: `${FINANCE_BASE_PATH}/movimientos`, icon: 'list', primary: true },
    { label: 'Cuentas', path: `${FINANCE_BASE_PATH}/cuentas`, icon: 'landmark' },
    { label: 'Presupuestos', path: `${FINANCE_BASE_PATH}/presupuestos`, icon: 'gauge', primary: true },
    { label: 'Categorías', path: `${FINANCE_BASE_PATH}/categorias`, icon: 'tag' },
    { label: 'Recurrentes', path: `${FINANCE_BASE_PATH}/recurrentes`, icon: 'repeat' },
    { label: 'Objetivos', path: `${FINANCE_BASE_PATH}/objetivos`, icon: 'target' },
    { label: 'Deudas', path: `${FINANCE_BASE_PATH}/deudas`, icon: 'hand-coins' },
    { label: 'Compartidos', path: `${FINANCE_BASE_PATH}/compartidos`, icon: 'users' },
    { label: 'Ajustes', path: `${FINANCE_BASE_PATH}/ajustes`, icon: 'settings' },
  ],
  homeWidget: () => import('./features/home-widget/finance-home-widget').then((m) => m.FinanceHomeWidget),
  pendingTypes: {
    [FINANCE_PENDING.uncategorized]: {
      label: 'Movimientos por categorizar',
      icon: 'circle-dashed',
      countLabel: (count) => (count === 1 ? '1 movimiento por categorizar' : `${count} movimientos por categorizar`),
    },
    [FINANCE_PENDING.recurring]: {
      label: 'Recurrentes por confirmar',
      icon: 'repeat',
      countLabel: (count) => (count === 1 ? '1 recurrente por confirmar' : `${count} recurrentes por confirmar`),
    },
  },
  pendingActions: {
    [FINANCE_PENDING.uncategorized]: () =>
      import('./features/pending/categorize-pending-action').then((m) => m.CategorizePendingAction),
    [FINANCE_PENDING.recurring]: () =>
      import('./features/pending/confirm-recurring-pending-action').then((m) => m.ConfirmRecurringPendingAction),
  },
  settings: () => import('./features/settings/finance-settings-panel').then((m) => m.FinanceSettingsPanel),
};

export const financeQuickAdd: QuickAddOpener = {
  id: 'finance.transaction',
  label: 'Nuevo movimiento',
  icon: 'plus',
  module: 'finance',
  open: () => inject(TransactionSheetLauncher).create(),
};

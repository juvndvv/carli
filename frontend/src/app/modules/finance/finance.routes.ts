import { inject } from '@angular/core';
import { CanActivateChildFn, Routes } from '@angular/router';
import { FinanceChanges } from './data-access/finance-changes';
import { provideFinanceIcons } from './ui/finance-icons';

export const refreshFinanceData: CanActivateChildFn = () => {
  inject(FinanceChanges).notify('accounts', 'periods', 'budgets', 'contacts');
  return true;
};

export const financeRoutes: Routes = [
  {
    path: '',
    providers: [provideFinanceIcons()],
    canActivateChild: [refreshFinanceData],
    children: [
      {
        path: '',
        pathMatch: 'full',
        loadComponent: () => import('./features/dashboard/dashboard-page').then((m) => m.DashboardPage),
      },
      {
        path: 'movimientos',
        loadComponent: () => import('./features/transactions/transactions-page').then((m) => m.TransactionsPage),
      },
      {
        path: 'movimientos/nuevo',
        loadComponent: () => import('./features/transactions/transactions-page').then((m) => m.TransactionsPage),
        data: { quickAdd: true },
      },
      {
        path: 'cuentas',
        loadComponent: () => import('./features/accounts/accounts-page').then((m) => m.AccountsPage),
      },
      {
        path: 'cuentas/:id',
        loadComponent: () => import('./features/accounts/account-detail-page').then((m) => m.AccountDetailPage),
      },
      {
        path: 'presupuestos',
        loadComponent: () => import('./features/budgets/budgets-page').then((m) => m.BudgetsPage),
      },
      {
        path: 'categorias',
        loadComponent: () => import('./features/categories/categories-page').then((m) => m.CategoriesPage),
      },
      {
        path: 'recurrentes',
        loadComponent: () => import('./features/recurring/recurring-page').then((m) => m.RecurringPage),
      },
      {
        path: 'objetivos',
        loadComponent: () => import('./features/goals/goals-page').then((m) => m.GoalsPage),
      },
      {
        path: 'objetivos/:id',
        loadComponent: () => import('./features/goals/goal-detail-page').then((m) => m.GoalDetailPage),
      },
      {
        path: 'deudas',
        loadComponent: () => import('./features/debts/debts-page').then((m) => m.DebtsPage),
      },
      {
        path: 'compartidos',
        loadComponent: () => import('./features/shared/shared-page').then((m) => m.SharedPage),
      },
      {
        path: 'compartidos/:contactId',
        loadComponent: () => import('./features/shared/contact-detail-page').then((m) => m.ContactDetailPage),
      },
      {
        path: 'ajustes',
        loadComponent: () => import('./features/settings/finance-settings-page').then((m) => m.FinanceSettingsPage),
      },
      {
        path: 'ajustes/bancos',
        loadComponent: () => import('./features/bank/bank-connections-page').then((m) => m.BankConnectionsPage),
      },
      {
        path: 'ajustes/bancos/:id/vincular',
        loadComponent: () => import('./features/bank/bank-link-page').then((m) => m.BankLinkPage),
      },
    ],
  },
];

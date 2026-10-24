import { IsoDate } from '@shared/dates/dates';
import { FinanceAccountRef, FinanceCategoryRef, RecurringMode } from './recurring.models';

export type DebtDirection = 'i_owe' | 'owed_to_me';

export interface Debt {
  id: string;
  name: string;
  direction: DebtDirection;
  contact_id: string | null;
  contact: { id: string; name: string } | null;
  principal_cents: number;
  paid_cents: number;
  pending_cents: number;
  progress_bp: number;
  start_date: IsoDate;
  due_date: IsoDate | null;
  installment_cents: number | null;
  installments_count: number | null;
  installments_paid: number;
  recurring_rule_id: string | null;
  next_payment_date: IsoDate | null;
  notes: string | null;
  closed: boolean;
  closed_at: string | null;
  created_at: string | null;
  updated_at: string | null;
}

export interface DebtsMeta {
  owed_to_me_cents: number;
  i_owe_cents: number;
}

export interface DebtPlanPayload {
  account_id: string;
  installment_cents: number;
  installments_count: number;
  first_payment_date: IsoDate;
  payment_day?: number | null;
  category_id?: string | null;
  mode?: RecurringMode;
}

export interface DebtPayload {
  name: string;
  direction: DebtDirection;
  principal_cents: number;
  start_date: IsoDate;
  contact_id: string | null;
  due_date: IsoDate | null;
  notes: string | null;
  plan?: DebtPlanPayload | null;
}

export interface DebtPaymentPayload {
  account_id: string;
  amount_cents: number;
  date: IsoDate;
  description?: string | null;
  notes?: string | null;
}

export interface DebtPayment {
  id: string;
  account_id: string;
  account: FinanceAccountRef;
  kind: string;
  amount_cents: number;
  date: IsoDate;
  category: FinanceCategoryRef | null;
  payee: string | null;
  description: string | null;
  status: 'pending' | 'cleared';
}

export const DEBT_DIRECTION_LABELS: Record<DebtDirection, string> = {
  i_owe: 'Debes',
  owed_to_me: 'Te deben',
};

export function debtInstallmentsLabel(debt: Pick<Debt, 'installment_cents' | 'installments_count' | 'installments_paid'>, formatMoney: (cents: number) => string): string {
  if (!debt.installment_cents || !debt.installments_count) {
    return 'Sin plan de pagos';
  }
  return `${formatMoney(debt.installment_cents)} / mes · ${Math.min(debt.installments_paid, debt.installments_count)} de ${debt.installments_count} cuotas`;
}

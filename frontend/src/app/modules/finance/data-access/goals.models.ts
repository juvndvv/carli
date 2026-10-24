import { IsoDate, MONTHS_SHORT, parseIsoDate } from '@shared/dates/dates';
import { FinanceAccountRef } from './recurring.models';

export interface SavingsGoal {
  id: string;
  name: string;
  target_cents: number;
  target_date: IsoDate | null;
  account_id: string | null;
  account: FinanceAccountRef | null;
  icon: string | null;
  color: string | null;
  achieved: boolean;
  achieved_at: string | null;
  saved_cents: number;
  remaining_cents: number;
  progress_bp: number;
  months_left: number | null;
  monthly_needed_cents: number | null;
  contributions_count: number;
  created_at: string | null;
  updated_at: string | null;
}

export interface GoalContribution {
  id: string;
  goal_id: string;
  amount_cents: number;
  date: IsoDate;
  note: string | null;
  transaction_id: string | null;
  created_at: string | null;
}

export interface SavingsGoalPayload {
  name: string;
  target_cents: number;
  target_date: IsoDate | null;
  account_id: string | null;
  icon: string | null;
}

export interface GoalContributionPayload {
  amount_cents: number;
  date: IsoDate;
  note: string | null;
}

export const GOAL_ICONS = [
  'piggy-bank',
  'shield',
  'plane',
  'laptop',
  'house',
  'car',
  'gift',
  'graduation-cap',
  'heart',
  'smartphone',
  'tree-palm',
  'target',
] as const;

export const DEFAULT_GOAL_ICON = 'piggy-bank';

export function goalPercent(goal: Pick<SavingsGoal, 'progress_bp'>): number {
  return Math.floor(goal.progress_bp / 100);
}

export function goalTargetMonthLabel(date: IsoDate | null): string | null {
  const parts = date ? parseIsoDate(date) : null;
  return parts ? `${MONTHS_SHORT[parts.month - 1]} ${parts.year}` : null;
}

export function sortGoals(goals: SavingsGoal[]): SavingsGoal[] {
  return [...goals].sort((a, b) => Number(a.achieved) - Number(b.achieved));
}

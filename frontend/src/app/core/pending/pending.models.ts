export interface PendingItem {
  module: string;
  type: string;
  id: string;
  title: string;
  subtitle: string | null;
  amount_cents: number | null;
  date: string;
  route: string;
  meta: Record<string, unknown>;
}

export interface PendingSummaryEntry {
  module: string;
  module_name: string;
  type: string;
  count: number;
}

export interface PendingSummary {
  total: number;
  by_module: PendingSummaryEntry[];
}

export interface PendingPageResponse {
  data: PendingItem[];
  meta: { has_more: boolean; next_cursor: string | null };
}

export interface PendingFilter {
  module: string | null;
  type: string | null;
}

export interface PendingTypeDescriptor {
  label: string;
  icon: string;
  countLabel: (count: number) => string;
}

export const ALL_PENDING: PendingFilter = { module: null, type: null };

export const samePendingFilter = (left: PendingFilter, right: PendingFilter): boolean =>
  left.module === right.module && left.type === right.type;

export function pendingTotalLabel(total: number): string {
  if (total === 0) {
    return 'Nada por revisar';
  }
  return total === 1 ? '1 elemento por revisar' : `${total} elementos por revisar`;
}

export const PENDING_QUERY = { module: 'modulo', type: 'tipo' } as const;

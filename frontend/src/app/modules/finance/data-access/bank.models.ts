import { IsoDate } from '@shared/dates/dates';
import { AccountType, BankConnectionStatus, CategoryKind, CategorySummary, Transaction } from './finance.models';

export interface Aspsp {
  name: string;
  country: string;
  logo: string | null;
  consent_days: number;
}

export interface BankLinkedAccount {
  id: string;
  name: string;
  external_account_uid: string;
  sync_from_date: IsoDate | null;
}

export interface BankConnection {
  id: string;
  provider: string;
  aspsp_name: string;
  aspsp_country: string;
  status: BankConnectionStatus;
  valid_until: string;
  expires_in_days: number;
  last_synced_at: string | null;
  last_error: string | null;
  bank_accounts_count: number;
  linked_accounts: BankLinkedAccount[];
  created_at: string | null;
  updated_at: string | null;
}

export interface BankAccountCandidate {
  external_account_uid: string;
  name: string | null;
  iban: string | null;
  currency: string | null;
  type: string | null;
  suggested_account_type: AccountType;
  linked_account: { id: string; name: string; type: AccountType; sync_from_date: IsoDate | null } | null;
}

export const NEW_ACCOUNT = 'new';

export interface BankAccountLinkInput {
  external_account_uid: string;
  account_id: string | null;
  name?: string | null;
  type?: AccountType | null;
  sync_from_date?: IsoDate | null;
}

export interface CategoryRule {
  id: string;
  pattern: string;
  kind: CategoryKind;
  category_id: string;
  category: CategorySummary | null;
  created_at: string | null;
  updated_at: string | null;
}

export interface SimilarTransactions {
  count: number;
  pattern: string;
  transaction_ids: string[];
}

export interface CategorizeSimilarResult {
  updated: number;
  transaction: Transaction;
  rule: CategoryRule | null;
}

export const EXPIRY_WARNING_DAYS = 7;

export type BankConnectionTone = 'positive' | 'warning' | 'negative' | 'neutral';

export interface BankConnectionState {
  label: string;
  tone: BankConnectionTone;
  canSync: boolean;
  canRenew: boolean;
}

export function expiresInLabel(days: number): string {
  if (days <= 0) {
    return 'Caduca hoy';
  }
  return days === 1 ? 'Caduca mañana' : `Caduca en ${days} días`;
}

export function bankConnectionState(connection: Pick<BankConnection, 'status' | 'expires_in_days'>): BankConnectionState {
  switch (connection.status) {
    case 'expired':
      return { label: 'Caducada', tone: 'negative', canSync: false, canRenew: true };
    case 'revoked':
      return { label: 'Desconectada', tone: 'neutral', canSync: false, canRenew: false };
    case 'error':
      return { label: 'Error', tone: 'negative', canSync: true, canRenew: true };
    default:
      return connection.expires_in_days <= EXPIRY_WARNING_DAYS
        ? { label: expiresInLabel(connection.expires_in_days), tone: 'warning', canSync: true, canRenew: true }
        : { label: 'Activa', tone: 'positive', canSync: true, canRenew: true };
  }
}

export const BANK_CALLBACK_ERRORS: Record<string, string> = {
  cancelado: 'Has cancelado la autorización en el banco. No se ha conectado nada.',
  estado: 'El enlace de vuelta del banco ha caducado o ya se había usado. Vuelve a intentarlo.',
  proveedor: 'El banco no ha podido completar la conexión. Inténtalo de nuevo en unos minutos.',
};

export function maskIban(iban: string | null): string | null {
  if (!iban) {
    return null;
  }
  const compact = iban.replace(/\s+/g, '');
  return compact.length <= 4 ? compact : `•••• ${compact.slice(-4)}`;
}

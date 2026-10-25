import { aBankLink } from '../testing/finance-fixtures';
import { bankBalanceSummary } from './bank-balance';

const plain = (text: string | null | undefined): string | null => (text == null ? null : text.replace(/\u00a0/g, ' '));

describe('bankBalanceSummary', () => {
  const now = new Date('2026-10-10T15:00:00+02:00');

  it('shows the bank balance and the signed difference', () => {
    const summary = bankBalanceSummary(aBankLink({ balance_at: '2026-10-10T11:00:00+00:00' }), now)!;
    expect(summary.bank).toBe('BBVA');
    expect(plain(summary.balance)).toBe('3.433,65 €');
    expect(plain(summary.difference)).toBe('+5,00 €');
    expect(summary.matches).toBe(false);
    expect(summary.updated).toBe('hoy a las 13:00');
  });

  it('says it matches when there is no difference', () => {
    const summary = bankBalanceSummary(aBankLink({ difference_cents: 0 }), now)!;
    expect(summary.matches).toBe(true);
    expect(summary.difference).toBeNull();
  });

  it('handles accounts without a bank balance yet', () => {
    expect(bankBalanceSummary(aBankLink({ balance_cents: null, difference_cents: null, balance_at: null }), now)).toMatchObject({
      balance: null,
      updated: null,
    });
    expect(bankBalanceSummary(null)).toBeNull();
  });
});

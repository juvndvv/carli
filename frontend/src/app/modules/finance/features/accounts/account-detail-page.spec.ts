import { aTransaction } from '../../testing/finance-fixtures';
import { balanceHistory } from './account-detail-page';

describe('balanceHistory', () => {
  it('walks back from the current balance day by day', () => {
    const points = balanceHistory(
      10000,
      [
        aTransaction({ date: '2026-10-24', amount_cents: -2000 }),
        aTransaction({ id: 'b', date: '2026-10-22', amount_cents: 5000 }),
        aTransaction({ id: 'c', date: '2026-10-26', amount_cents: -1000 }),
      ],
      '2026-10-24',
      4,
    );
    expect(points).toEqual([
      { date: '2026-10-21', balance: 8000 },
      { date: '2026-10-22', balance: 13000 },
      { date: '2026-10-23', balance: 13000 },
      { date: '2026-10-24', balance: 11000 },
    ]);
  });
});

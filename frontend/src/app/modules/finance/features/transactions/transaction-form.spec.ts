import { parseTagInput, previewShares, signedAmount, splitRemaining, toSharesInput, toSplitInputs } from './transaction-form';

describe('transaction form helpers', () => {
  it('applies the sign of the movement kind', () => {
    expect(signedAmount('expense', 4250)).toBe(-4250);
    expect(signedAmount('income', 4250)).toBe(4250);
    expect(signedAmount('transfer', -100)).toBe(100);
    expect(signedAmount('adjustment', -100)).toBe(-100);
  });

  it('computes how much of a split is left', () => {
    expect(splitRemaining(-10000, [{ categoryId: 'a', amount: 6000 }, { categoryId: 'b', amount: null }])).toBe(4000);
    expect(toSplitInputs('expense', [{ categoryId: 'a', amount: 6000 }, { categoryId: null, amount: 1 }])).toEqual([
      { category_id: 'a', amount_cents: -6000 },
    ]);
  });

  it('previews equal shares including me', () => {
    const preview = previewShares(8000, 'equal', true, [{ contactId: 'ana', name: 'Ana', percentage: null, amount: null }]);
    expect(preview).toEqual([{ contactId: 'ana', name: 'Ana', amount: 4000 }]);
  });

  it('spreads the remainder when I am not part of an equal split', () => {
    const items = [
      { contactId: 'a', name: 'A', percentage: null, amount: null },
      { contactId: 'b', name: 'B', percentage: null, amount: null },
    ];
    expect(previewShares(1001, 'equal', false, items).map((item) => item.amount)).toEqual([501, 500]);
  });

  it('previews percentage and amount shares without floats', () => {
    expect(previewShares(-1999, 'percentage', true, [{ contactId: 'a', name: 'A', percentage: 33.33, amount: null }])[0].amount).toBe(666);
    expect(previewShares(5000, 'amount', true, [{ contactId: 'a', name: 'A', percentage: null, amount: 1200 }])[0].amount).toBe(1200);
  });

  it('builds the shares payload for each mode', () => {
    const items = [{ contactId: 'ana', name: 'Ana', percentage: 50, amount: 100 }];
    expect(toSharesInput('equal', false, items)).toEqual({ mode: 'equal', include_self: false, items: [{ contact_id: 'ana' }] });
    expect(toSharesInput('percentage', true, items)).toEqual({ mode: 'percentage', items: [{ contact_id: 'ana', percentage: 50 }] });
    expect(toSharesInput('amount', true, items)).toEqual({ mode: 'amount', items: [{ contact_id: 'ana', amount_cents: 100 }] });
  });

  it('normalises typed tags', () => {
    expect(parseTagInput('#Casa, vacaciones-2026  #Finde')).toEqual(['casa', 'vacaciones-2026', 'finde']);
  });
});

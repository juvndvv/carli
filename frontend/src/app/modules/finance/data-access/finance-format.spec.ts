import { budgetLimit, budgetNote, budgetUsageLabel, budgetUsageRatio, daysLeftLabel, formatBasisPoints, formatPercentRounded, inDaysLabel, transactionAmountLabel, transactionTitle, transactionTone } from './finance-format';
import { aTransaction } from '../testing/finance-fixtures';
import { BudgetRow } from './finance.models';

const eur = (text: string) => text.replace(/ €/g, '\u00a0€');

describe('finance format', () => {
  it('formats basis points as Spanish percentages', () => {
    expect(formatBasisPoints(3490)).toBe('34,9 %');
    expect(formatBasisPoints(-1800, true)).toBe('−18 %');
    expect(formatBasisPoints(90, true)).toBe('+0,9 %');
    expect(formatBasisPoints(null)).toBe('—');
    expect(formatPercentRounded(10967)).toBe('110 %');
  });

  it('formats movement amounts by kind', () => {
    expect(transactionAmountLabel(aTransaction())).toBe(eur('−42,50 €'));
    expect(transactionAmountLabel(aTransaction({ kind: 'income', amount_cents: 265000 }))).toBe(eur('+2.650,00 €'));
    expect(transactionAmountLabel(aTransaction({ kind: 'transfer', amount_cents: -50000 }))).toBe(eur('500,00 €'));
    expect(transactionTone(aTransaction({ kind: 'transfer', amount_cents: -50000 }))).toBe('muted');
    expect(transactionTone(aTransaction({ kind: 'income', amount_cents: 1 }))).toBe('positive');
  });

  it('picks a readable title', () => {
    expect(transactionTitle(aTransaction())).toBe('Mercadona');
    expect(transactionTitle(aTransaction({ payee: null, description: null }))).toBe('Alimentación');
    expect(transactionTitle(aTransaction({ payee: null, kind: 'transfer', amount_cents: -1, category: null }))).toBe('Transferencia enviada');
  });

  it('writes budget and day notes in the second person', () => {
    expect(budgetNote('ok', 12000)).toBe(eur('Te quedan 120,00 €'));
    expect(budgetNote('exceeded', -1450)).toBe(eur('Excedido en 14,50 €'));
    expect(daysLeftLabel(3)).toBe('quedan 3 días');
    expect(daysLeftLabel(1)).toBe('queda 1 día');
    expect(inDaysLabel(2)).toBe('pasado mañana');
    expect(inDaysLabel(5)).toBe('en 5 días');
  });

  it('keeps the planned limit visible when a carried excess makes the available amount negative', () => {
    const row = {
      amount_cents: 15000,
      rollover_in_cents: -33313,
      available_cents: -18313,
      spent_cents: 4721,
      remaining_cents: -23034,
    } as BudgetRow;
    expect(budgetLimit(row)).toBe(15000);
    expect(budgetUsageRatio(row)).toBeCloseTo(38034 / 15000);
    expect(budgetUsageLabel(row)).toBe('254 %');
  });

  it('adds a carried surplus to the limit', () => {
    const row = { amount_cents: 10000, rollover_in_cents: 2000, available_cents: 12000, spent_cents: 6000 } as BudgetRow;
    expect(budgetLimit(row)).toBe(12000);
    expect(budgetUsageLabel(row)).toBe('50 %');
    expect(budgetUsageLabel({ ...row, amount_cents: 0, rollover_in_cents: 0, available_cents: 0 })).toBe('Excedido');
  });
});

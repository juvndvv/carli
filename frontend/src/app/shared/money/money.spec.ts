import { formatCentsForInput, formatMoney, formatMoneyCompact, MINUS_SIGN, parseMoneyInput } from './money';
import { MoneyPipe } from './money.pipe';

const NBSP = ' ';

describe('formatMoney', () => {
  it('formats cents as es-ES euros with grouping on four digit amounts', () => {
    expect(formatMoney(269500)).toBe(`2.695,00${NBSP}€`);
    expect(formatMoney(4250)).toBe(`42,50${NBSP}€`);
    expect(formatMoney(123456789)).toBe(`1.234.567,89${NBSP}€`);
  });

  it('uses a true minus sign for negative amounts', () => {
    expect(formatMoney(-175527)).toBe(`${MINUS_SIGN}1.755,27${NBSP}€`);
  });

  it('adds a plus sign only in signed mode', () => {
    expect(formatMoney(4500, 'signed')).toBe(`+45,00${NBSP}€`);
    expect(formatMoney(4500)).toBe(`45,00${NBSP}€`);
    expect(formatMoney(0, 'signed')).toBe(`0,00${NBSP}€`);
  });

  it('drops the sign in absolute mode', () => {
    expect(formatMoney(-50000, 'absolute')).toBe(`500,00${NBSP}€`);
  });

  it('returns an empty string for missing values', () => {
    expect(formatMoney(null)).toBe('');
    expect(formatMoney(undefined)).toBe('');
  });

  it('formats compact axis values', () => {
    expect(formatMoneyCompact(400000)).toBe('4 k€');
    expect(formatMoneyCompact(150000)).toBe('1,5 k€');
    expect(formatMoneyCompact(4250)).toBe('43 €');
  });
});

describe('MoneyPipe', () => {
  const pipe = new MoneyPipe();

  it('delegates to formatMoney with the requested display', () => {
    expect(pipe.transform(-4250, 'signed')).toBe(`${MINUS_SIGN}42,50${NBSP}€`);
    expect(pipe.transform(265000, 'signed')).toBe(`+2.650,00${NBSP}€`);
    expect(pipe.transform(null)).toBe('');
  });
});

describe('parseMoneyInput', () => {
  it.each([
    ['42,50', 4250],
    ['42,5', 4250],
    ['42', 4200],
    ['0,99', 99],
    [',5', 50],
    ['1.234,56', 123456],
    ['1.234', 123400],
    ['12.345.678', 1234567800],
    ['42.50', 4250],
    ['42.5', 4250],
    [' 1 234,56 € ', 123456],
    ['+12,00', 1200],
    ['-12,30', -1230],
    [`${MINUS_SIGN}12,30`, -1230],
  ])('parses %s as %i cents', (raw, cents) => {
    expect(parseMoneyInput(raw)).toBe(cents);
  });

  it.each(['', '   ', 'abc', '12,345', '1,2,3', '1.23.4', '12a', '1.2345,00'])('rejects %s', (raw) => {
    expect(parseMoneyInput(raw)).toBeNull();
  });

  it('never produces floating point artifacts', () => {
    expect(parseMoneyInput('0,10')! + parseMoneyInput('0,20')!).toBe(30);
    expect(parseMoneyInput('19,99')).toBe(1999);
  });
});

describe('formatCentsForInput', () => {
  it('renders editable text with comma decimals', () => {
    expect(formatCentsForInput(123456)).toBe('1234,56');
    expect(formatCentsForInput(5)).toBe('0,05');
    expect(formatCentsForInput(-1230)).toBe('-12,30');
    expect(formatCentsForInput(null)).toBe('');
  });

  it('can group thousands for display', () => {
    expect(formatCentsForInput(123456, true)).toBe('1.234,56');
  });
});

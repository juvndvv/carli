export type MoneyDisplay = 'plain' | 'signed' | 'absolute';

export const MINUS_SIGN = '−';

const currencyFormatter = new Intl.NumberFormat('es-ES', {
  style: 'currency',
  currency: 'EUR',
  useGrouping: 'always',
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

const decimalFormatter = new Intl.NumberFormat('es-ES', {
  useGrouping: 'always',
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

const compactFormatter = new Intl.NumberFormat('es-ES', {
  useGrouping: 'always',
  maximumFractionDigits: 1,
});

const centsToUnits = (cents: number): number => cents / 100;

export function formatMoney(cents: number | null | undefined, display: MoneyDisplay = 'plain'): string {
  if (cents === null || cents === undefined || Number.isNaN(cents)) {
    return '';
  }
  const formatted = currencyFormatter.format(centsToUnits(Math.abs(cents)));
  if (display === 'absolute' || cents === 0) {
    return formatted;
  }
  if (cents < 0) {
    return `${MINUS_SIGN}${formatted}`;
  }
  return display === 'signed' ? `+${formatted}` : formatted;
}

export function formatMoneyCompact(cents: number): string {
  const sign = cents < 0 ? MINUS_SIGN : '';
  const absolute = Math.abs(cents);
  if (absolute >= 100_000) {
    return `${sign}${compactFormatter.format(absolute / 100_000)} k€`;
  }
  return `${sign}${Math.round(absolute / 100)} €`;
}

export function formatCentsForInput(cents: number | null | undefined, grouping = false): string {
  if (cents === null || cents === undefined) {
    return '';
  }
  const sign = cents < 0 ? '-' : '';
  const absolute = Math.abs(Math.trunc(cents));
  if (grouping) {
    return `${sign}${decimalFormatter.format(absolute / 100)}`;
  }
  const units = Math.floor(absolute / 100);
  const fraction = String(absolute % 100).padStart(2, '0');
  return `${sign}${units},${fraction}`;
}

const GROUPED_WITH_DOTS = /^\d{1,3}(\.\d{3})+$/;

export function parseMoneyInput(raw: string | null | undefined): number | null {
  if (raw === null || raw === undefined) {
    return null;
  }
  let text = raw.replace(/[\s\u00a0\u202f\u20ac]/g, '').replace(/^\+/, '');
  if (text === '') {
    return null;
  }
  let negative = false;
  if (text.startsWith('-') || text.startsWith(MINUS_SIGN)) {
    negative = true;
    text = text.slice(1);
  }

  let integerPart: string;
  let fractionPart = '';
  if (text.includes(',')) {
    const pieces = text.split(',');
    if (pieces.length !== 2) {
      return null;
    }
    integerPart = pieces[0].replace(/\./g, '');
    fractionPart = pieces[1];
    if (pieces[0].includes('.') && !GROUPED_WITH_DOTS.test(pieces[0])) {
      return null;
    }
  } else if (GROUPED_WITH_DOTS.test(text)) {
    integerPart = text.replace(/\./g, '');
  } else if (text.includes('.')) {
    const pieces = text.split('.');
    if (pieces.length !== 2) {
      return null;
    }
    [integerPart, fractionPart] = pieces;
  } else {
    integerPart = text;
  }

  if (integerPart === '') {
    integerPart = '0';
  }
  if (!/^\d+$/.test(integerPart) || !/^\d{0,2}$/.test(fractionPart)) {
    return null;
  }
  const cents = Number(integerPart) * 100 + Number(fractionPart.padEnd(2, '0'));
  if (!Number.isSafeInteger(cents)) {
    return null;
  }
  return negative && cents !== 0 ? -cents : cents;
}

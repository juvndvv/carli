import { bankConnectionState, expiresInLabel, maskIban } from './bank.models';

describe('bank connection state', () => {
  it('maps statuses to labels, tones and actions', () => {
    expect(bankConnectionState({ status: 'active', expires_in_days: 60 })).toEqual({
      label: 'Activa',
      tone: 'positive',
      canSync: true,
      canRenew: true,
    });
    expect(bankConnectionState({ status: 'active', expires_in_days: 7 })).toMatchObject({ label: 'Caduca en 7 días', tone: 'warning' });
    expect(bankConnectionState({ status: 'expired', expires_in_days: 0 })).toMatchObject({ label: 'Caducada', canSync: false, canRenew: true });
    expect(bankConnectionState({ status: 'error', expires_in_days: 30 })).toMatchObject({ label: 'Error', tone: 'negative', canSync: true });
    expect(bankConnectionState({ status: 'revoked', expires_in_days: 30 })).toMatchObject({ canSync: false, canRenew: false });
  });

  it('words the remaining days', () => {
    expect(expiresInLabel(0)).toBe('Caduca hoy');
    expect(expiresInLabel(1)).toBe('Caduca mañana');
    expect(expiresInLabel(3)).toBe('Caduca en 3 días');
  });

  it('masks the iban to its last four digits', () => {
    expect(maskIban('ES91 2100 0418 4502 0005 1332')).toBe('•••• 1332');
    expect(maskIban(null)).toBeNull();
  });
});

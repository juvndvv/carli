import {
  activeFilterCount,
  EMPTY_FILTERS,
  filtersFromParams,
  filtersToApiQuery,
  filtersToParams,
} from './transaction-filters';

describe('transaction filters', () => {
  it('defaults to the current period without params', () => {
    expect(filtersFromParams({})).toEqual(EMPTY_FILTERS);
  });

  it('parses Spanish query params into filters', () => {
    const filters = filtersFromParams({
      periodo: 'period-1',
      cuenta: 'a,b',
      categoria: ['none'],
      etiqueta: '#Casa',
      tipo: 'gasto,ingreso',
      min: '1000',
      max: 'abc',
      estado: 'pendiente',
    });
    expect(filters.period).toBe('period-1');
    expect(filters.accountIds).toEqual(['a', 'b']);
    expect(filters.categoryIds).toEqual(['none']);
    expect(filters.tags).toEqual(['casa']);
    expect(filters.kinds).toEqual(['expense', 'income']);
    expect(filters.min).toBe(1000);
    expect(filters.max).toBeNull();
    expect(filters.status).toBe('pending');
    expect(activeFilterCount(filters)).toBe(6);
  });

  it('searches every period when a text query arrives without a period', () => {
    expect(filtersFromParams({ q: 'mercadona' }).period).toBe('all');
    expect(filtersFromParams({ q: 'mercadona', periodo: 'actual' }).period).toBe('current');
  });

  it('round-trips filters through query params', () => {
    const filters = { ...EMPTY_FILTERS, period: 'all', accountIds: ['a'], kinds: ['transfer' as const], q: 'luz' };
    const params = filtersToParams(filters);
    expect(params['periodo']).toBeNull();
    expect(params['tipo']).toBe('transferencia');
    expect(filtersFromParams(Object.fromEntries(Object.entries(params).filter(([, value]) => value !== null)))).toEqual(filters);
    expect(filtersToParams({ ...EMPTY_FILTERS, period: 'all' })['periodo']).toBe('todos');
    expect(filtersToParams({ ...EMPTY_FILTERS, q: 'x' })['periodo']).toBe('actual');
  });

  it('maps filters to API query values', () => {
    expect(filtersToApiQuery({ ...EMPTY_FILTERS, min: 500 }, 'period-current')).toMatchObject({
      period_id: 'period-current',
      min: 500,
      q: null,
    });
    expect(filtersToApiQuery({ ...EMPTY_FILTERS, period: 'all' }, 'period-current')['period_id']).toBeNull();
    expect(filtersToApiQuery({ ...EMPTY_FILTERS, from: '2026-01-01' }, 'period-current')['period_id']).toBeNull();
  });

  it('maps the Sin categoría filter between query params and the API', () => {
    const filters = filtersFromParams({ sin_categoria: '1', periodo: 'todos' });
    expect(filters.uncategorized).toBe(true);
    expect(filters.period).toBe('all');
    expect(activeFilterCount(filters)).toBe(1);
    expect(filtersToParams(filters)['sin_categoria']).toBe('1');
    expect(filtersToApiQuery(filters, 'period-current')['uncategorized']).toBe(1);
    expect(filtersToApiQuery(EMPTY_FILTERS, 'period-current')['uncategorized']).toBeNull();
    expect(filtersFromParams({ sin_categoria: '0' }).uncategorized).toBe(false);
  });
});

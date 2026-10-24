import { buildDonut } from './dashboard-page';
import { DashboardCategoryGroup } from '../../data-access/finance.models';

const group = (name: string, amount: number, color: string | null): DashboardCategoryGroup => ({
  category_id: name,
  name,
  icon: null,
  color,
  amount_cents: amount,
  percent_bp: 0,
  children: [],
});

describe('buildDonut', () => {
  it('keeps each category colour and resolves clashes with free slots', () => {
    const slices = buildDonut([group('Hogar', 5000, 'c1'), group('Regalos', 1000, 'c1'), group('Ocio', 3000, 'c4')]);
    expect(slices.map((slice) => [slice.label, slice.color])).toEqual([
      ['Hogar', 1],
      ['Ocio', 4],
      ['Regalos', 2],
    ]);
    expect(slices[0].percent).toBe('56 %');
  });

  it('groups everything after the eighth slice into Otros', () => {
    const groups = Array.from({ length: 10 }, (_, index) => group(`C${index}`, 1000 - index, `c${(index % 8) + 1}`));
    const slices = buildDonut(groups);
    expect(slices).toHaveLength(8);
    expect(slices.at(-1)).toMatchObject({ label: 'Otros', amount: 993 + 992 + 991, color: 'text-3' });
  });
});

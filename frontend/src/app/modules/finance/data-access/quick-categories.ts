import { UiCategoryOption } from '@ui/category-picker/category-picker';
import { CategoryEntry } from './categories.service';

export function quickCategoryEntries(
  entries: CategoryEntry[],
  recentIds: string[],
  limit: number,
  selectedId: string | null = null,
): CategoryEntry[] {
  const byId = new Map(entries.map((entry) => [entry.category.id, entry]));
  const chosen: CategoryEntry[] = [];
  const push = (entry: CategoryEntry | undefined) => {
    if (entry && !chosen.includes(entry)) {
      chosen.push(entry);
    }
  };
  recentIds.forEach((id) => push(byId.get(id)));
  entries.filter((entry) => entry.parent === null).forEach(push);
  entries.forEach(push);
  const quick = chosen.slice(0, limit);
  const selected = selectedId ? byId.get(selectedId) : undefined;
  if (selected && !quick.includes(selected) && quick.length > 0) {
    quick[quick.length - 1] = selected;
  }
  return quick;
}

export function toCategoryOption(entry: CategoryEntry): UiCategoryOption {
  return { id: entry.category.id, name: entry.category.name, icon: entry.icon };
}

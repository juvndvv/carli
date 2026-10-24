import { formatShortDate, toIsoDate } from '@shared/dates/dates';

const relativeFormatter = new Intl.RelativeTimeFormat('es-ES', { numeric: 'auto' });

export function formatTimeAgo(value: string, now: Date = new Date()): string {
  const instant = new Date(value);
  if (Number.isNaN(instant.getTime())) {
    return '';
  }
  const seconds = Math.round((instant.getTime() - now.getTime()) / 1000);
  const absolute = Math.abs(seconds);
  if (absolute < 60) {
    return 'ahora';
  }
  if (absolute < 3600) {
    return relativeFormatter.format(Math.round(seconds / 60), 'minute');
  }
  if (absolute < 86_400) {
    return relativeFormatter.format(Math.round(seconds / 3600), 'hour');
  }
  if (absolute < 7 * 86_400) {
    return relativeFormatter.format(Math.round(seconds / 86_400), 'day');
  }
  return formatShortDate(toIsoDate(instant));
}

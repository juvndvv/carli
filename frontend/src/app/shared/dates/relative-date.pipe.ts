import { Pipe, PipeTransform } from '@angular/core';
import { formatRelativeDay, IsoDate, RelativeDateStyle, todayIso } from './dates';

@Pipe({ name: 'relativeDate' })
export class RelativeDatePipe implements PipeTransform {
  transform(value: IsoDate | null | undefined, style: RelativeDateStyle = 'lower', today: IsoDate = todayIso()): string {
    if (!value) {
      return '';
    }
    return formatRelativeDay(value, today, style);
  }
}

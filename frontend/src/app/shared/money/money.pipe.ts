import { Pipe, PipeTransform } from '@angular/core';
import { formatMoney, MoneyDisplay } from './money';

@Pipe({ name: 'money' })
export class MoneyPipe implements PipeTransform {
  transform(cents: number | null | undefined, display: MoneyDisplay = 'plain'): string {
    return formatMoney(cents, display);
  }
}

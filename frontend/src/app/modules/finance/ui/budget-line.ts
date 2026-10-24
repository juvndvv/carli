import { booleanAttribute, ChangeDetectionStrategy, Component, computed, input } from '@angular/core';
import { MoneyPipe } from '@shared/money/money.pipe';
import { UiIcon } from '@ui/icon/icon';
import { UiProgress } from '@ui/progress/progress';
import { budgetConsumed, budgetLimit, budgetNote, budgetUsageRatio } from '../data-access/finance-format';
import { BudgetRow } from '../data-access/finance.models';

@Component({
  selector: 'fin-budget-line',
  imports: [UiProgress, UiIcon, MoneyPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="head small">
      <span class="name">{{ name() }}</span>
      <span class="num muted">{{ row().spent_cents | money }} / {{ limit() | money }}</span>
    </div>
    <ui-progress [ratio]="ratio()" [warnAt]="warnAt()" [label]="'Presupuesto de ' + name()" />
    <div class="small note">
      @if (exceeded()) {
        <span class="neg"><ui-icon name="circle-alert" [size]="14" /> {{ note() }}</span>
      } @else {
        <span class="muted">{{ note() }}</span>
      }
      @if (showProjection() && row().projected_status !== 'ok' && row().projected_status !== row().status) {
        <span class="faint"> · Proyección {{ row().projected_cents | money }}</span>
      }
      @if (row().rollover_in_cents !== 0) {
        <span class="faint"> · {{ row().rollover_in_cents > 0 ? 'Arrastras' : 'Arrastras un exceso de' }} {{ row().rollover_in_cents | money: 'absolute' }}</span>
      }
    </div>
  `,
  styles: `
    :host {
      display: block;
      min-width: 0;
    }
    .head {
      display: flex;
      justify-content: space-between;
      gap: 12px;
      margin-bottom: 6px;
    }
    .name {
      flex: 0 0 auto;
      max-width: 62%;
      font-weight: 550;
      font-size: 14px;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .num {
      flex: 0 1 auto;
      min-width: 0;
      text-align: right;
    }
    .note {
      margin-top: 4px;
    }
    .note ui-icon {
      vertical-align: -2px;
    }
  `,
})
export class FinBudgetLine {
  readonly row = input.required<BudgetRow>();
  readonly warnAt = input(0.8);
  readonly showProjection = input(false, { transform: booleanAttribute });

  protected readonly name = computed(() => {
    const category = this.row().category;
    return category.parent ? `${category.parent} › ${category.name}` : category.name;
  });
  protected readonly limit = computed(() => budgetLimit(this.row()));
  protected readonly ratio = computed(() => {
    const ratio = budgetUsageRatio(this.row());
    return ratio ?? (budgetConsumed(this.row()) > 0 ? 1.01 : 0);
  });
  protected readonly exceeded = computed(() => this.row().status === 'exceeded');
  protected readonly note = computed(() => budgetNote(this.row().status, this.row().remaining_cents));
}

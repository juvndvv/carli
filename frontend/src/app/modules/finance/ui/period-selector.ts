import { CdkMenu, CdkMenuItem, CdkMenuTrigger } from '@angular/cdk/menu';
import { ChangeDetectionStrategy, Component, computed, input, model } from '@angular/core';
import { UiButton } from '@ui/button/button';
import { UiIcon } from '@ui/icon/icon';
import { Period } from '../data-access/finance.models';

export function periodButtonLabel(period: Period): string {
  return `${period.name} · ${period.is_current ? period.range_label.replace(/–.*$/, '– hoy') : period.range_label}`;
}

@Component({
  selector: 'fin-period-selector',
  imports: [UiButton, UiIcon, CdkMenuTrigger, CdkMenu, CdkMenuItem],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <button
      ui-button
      type="button"
      variant="ghost"
      size="sm"
      icon="chevron-left"
      iconOnly
      aria-label="Periodo anterior"
      [disabled]="!older()"
      (click)="select(older())"
    ></button>
    <button
      ui-button
      type="button"
      variant="secondary"
      size="sm"
      class="label"
      [cdkMenuTriggerFor]="menu"
      [disabled]="periods().length === 0"
    >
      @if (selected(); as period) {
        <span class="d-only">{{ buttonLabel(period) }}</span>
        <span class="m-only">{{ period.short_name }}</span>
      } @else {
        Periodo
      }
    </button>
    <button
      ui-button
      type="button"
      variant="ghost"
      size="sm"
      icon="chevron-right"
      iconOnly
      aria-label="Periodo siguiente"
      [disabled]="!newer()"
      (click)="select(newer())"
    ></button>
    <ng-template #menu>
      <div class="ui-menu periods" cdkMenu aria-label="Periodos">
        @for (period of periods(); track period.id) {
          <button type="button" class="ui-menu-item" cdkMenuItem (cdkMenuItemTriggered)="select(period)">
            <span class="text">
              <span>{{ period.name }}</span>
              <span class="small faint">{{ period.range_label }}{{ period.is_current ? ' · en curso' : '' }}</span>
            </span>
            @if (period.id === selected()?.id) {
              <ui-icon name="check" [size]="16" />
            }
          </button>
        }
      </div>
    </ng-template>
  `,
  styles: `
    :host {
      display: inline-flex;
      align-items: center;
      gap: 4px;
    }
    .periods {
      max-height: 360px;
      overflow: auto;
      min-width: 260px;
    }
    .periods .ui-menu-item {
      min-height: 48px;
    }
    .text {
      display: flex;
      flex-direction: column;
      flex: 1;
      min-width: 0;
    }
  `,
})
export class FinPeriodSelector {
  readonly periods = input.required<Period[]>();
  readonly value = model<string | null>(null);

  protected readonly selected = computed(
    () => this.periods().find((period) => period.id === this.value()) ?? this.periods().find((period) => period.is_current) ?? null,
  );
  private readonly index = computed(() => {
    const selected = this.selected();
    return selected ? this.periods().findIndex((period) => period.id === selected.id) : -1;
  });
  protected readonly older = computed(() => (this.index() >= 0 ? (this.periods()[this.index() + 1] ?? null) : null));
  protected readonly newer = computed(() => (this.index() > 0 ? this.periods()[this.index() - 1] : null));

  protected buttonLabel(period: Period): string {
    return periodButtonLabel(period);
  }

  protected select(period: Period | null): void {
    if (period) {
      this.value.set(period.id);
    }
  }
}
